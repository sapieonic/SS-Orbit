package messaging

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/messaging/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/events"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
	"github.com/sapionic/orbit/backend/internal/platform/logx"
	"github.com/sapionic/orbit/backend/internal/xmod"
)

// Event subscribers. Delivery is at least once, so every subscriber is
// idempotent through a unique key: FA alerts on (fa, kind, ref), HO alerts on
// (kind, farmer), notices on (farmer, ref_type, ref_id). Deliveries hang off
// the notice and are only created when the notice is new.

func (m *Module) subscribe(bus *events.Bus) {
	events.Handle(bus, "messaging.new_farmer_alerts", m.svc.onFarmerRegistered)
	events.Handle(bus, "messaging.welcome_sms", m.svc.onWelcome)
	events.Handle(bus, "messaging.profile_completed_alerts", m.svc.onProfileCompleted)
	events.Handle(bus, "messaging.callback_alert", m.svc.onCallbackRequested)
	events.Handle(bus, "messaging.fa_change_sms", m.svc.onFarmersReassigned)
	events.Handle(bus, "messaging.visit_advice", m.svc.onVisitLogged)
}

// gone reports (and logs) a record that disappeared; retrying will not help.
func gone(ctx context.Context, err error, what string) bool {
	if apperr.Is(err, apperr.KindNotFound) {
		logx.From(ctx).WarnContext(ctx, "messaging: subscriber skipped, record not found", "what", what)
		return true
	}
	return false
}

// onFarmerRegistered alerts the assigned FA about a self sign-up, and HO about
// every new farmer (plus farmer_without_fa when the farmer's village is known
// but no FA covers it).
func (s *Service) onFarmerRegistered(ctx context.Context, e events.FarmerRegistered) error {
	f, err := s.farmerSummary(ctx, e.FarmerID)
	if err != nil {
		if gone(ctx, err, "farmer") {
			return nil
		}
		return err
	}
	villageID := f.VillageID
	if !villageID.Valid && e.VillageID != nil {
		villageID = someUUID(*e.VillageID)
	}
	return s.newFarmerAlerts(ctx, f, villageID, e.Source, e.Source == "self")
}

// onProfileCompleted handles a self sign-up picking their village: their FA is
// now known, so alert the FA and complete the HO alert with the district.
func (s *Service) onProfileCompleted(ctx context.Context, e events.FarmerProfileCompleted) error {
	f, err := s.farmerSummary(ctx, e.FarmerID)
	if err != nil {
		if gone(ctx, err, "farmer") {
			return nil
		}
		return err
	}
	return s.newFarmerAlerts(ctx, f, someUUID(e.VillageID), "self", true)
}

func (s *Service) newFarmerAlerts(ctx context.Context, f xmod.FarmerSummary, villageID uuid.NullUUID, source string, alertFA bool) error {
	v, err := s.village(ctx, villageID)
	if err != nil {
		return err
	}
	var fa *xmod.FieldAssistant
	if f.AssignedFAID.Valid {
		got, err := s.fieldAssistant(ctx, f.AssignedFAID.UUID)
		if err != nil && !gone(ctx, err, "field_assistant") {
			return err
		}
		if err == nil {
			fa = &got
		}
	}
	payload := map[string]any{"farmer_name": derefStr(f.Name), "farmer_name_te": derefStr(f.NameTe), "source": source}
	var district uuid.NullUUID
	if v != nil {
		district = someUUID(v.DistrictID)
		payload["village_name"], payload["mandal_name"], payload["district_name"] = v.Name, v.MandalName, v.DistrictName
	}
	if fa != nil {
		payload["fa_name"] = fa.Name
	}
	return s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		if alertFA && f.AssignedFAID.Valid {
			t := faAlertNewFarmerText(f, v)
			if _, _, err := s.insertFAAlert(ctx, tx, q, store.InsertFAAlertParams{
				ID: ids.New(), FaID: f.AssignedFAID.UUID, Kind: faAlertNewFarmer, FarmerID: someUUID(f.ID),
				RefID: someUUID(f.ID), Title: t.TitleEn, Body: &t.BodyEn, TitleTe: &t.TitleTe, BodyTe: &t.BodyTe,
			}); err != nil {
				return err
			}
		}
		if err := s.upsertHOAlert(ctx, tx, q, hoAlertNewFarmer, f.ID, f.AssignedFAID, district, payload); err != nil {
			return err
		}
		if v != nil && !f.AssignedFAID.Valid {
			return s.upsertHOAlert(ctx, tx, q, hoAlertFarmerWithoutFA, f.ID, uuid.NullUUID{}, district, payload)
		}
		return nil
	})
}

// onCallbackRequested puts a "call me back" card in the FA's Alerts tab.
func (s *Service) onCallbackRequested(ctx context.Context, e events.CallbackRequested) error {
	f, err := s.farmerSummary(ctx, e.FarmerID)
	if err != nil && !gone(ctx, err, "farmer") {
		return err
	}
	if err != nil {
		f = xmod.FarmerSummary{ID: e.FarmerID}
	}
	t := faAlertCallbackText(f)
	return s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		_, _, err := s.insertFAAlert(ctx, tx, q, store.InsertFAAlertParams{
			ID: ids.New(), FaID: e.FAID, Kind: faAlertCallback, FarmerID: someUUID(e.FarmerID),
			RefID: someUUID(e.CallbackID), Title: t.TitleEn, Body: &t.BodyEn, TitleTe: &t.TitleTe, BodyTe: &t.BodyTe,
		})
		return err
	})
}

// onWelcome sends the welcome SMS (and an inbox notice) to a new farmer.
func (s *Service) onWelcome(ctx context.Context, e events.FarmerRegistered) error {
	f, err := s.farmerSummary(ctx, e.FarmerID)
	if err != nil {
		if gone(ctx, err, "farmer") {
			return nil
		}
		return err
	}
	text, sms := welcomeNotice(f)
	return s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		return s.refNotice(ctx, tx, q, f.ID, "system", "system", "welcome", f.ID, text, sms)
	})
}

// onFarmersReassigned tells each farmer the name and phone of their new FA.
// The event ID keys the notices, so a later move back to the same FA is a new message.
func (s *Service) onFarmersReassigned(ctx context.Context, e events.FarmersReassigned) error {
	fa, err := s.fieldAssistant(ctx, e.ToFAID)
	if err != nil {
		if gone(ctx, err, "field_assistant") {
			return nil
		}
		return err
	}
	ref := e.ToFAID
	if meta, ok := events.MetaFrom(ctx); ok && meta.EventID != uuid.Nil {
		ref = meta.EventID
	}
	farmerIDs := dedupe(e.FarmerIDs)
	for start := 0; start < len(farmerIDs); start += fanoutBatchSize {
		batch := farmerIDs[start:min(start+fanoutBatchSize, len(farmerIDs))]
		farmers, err := s.farmerSummaries(ctx, batch)
		if err != nil {
			return err
		}
		err = s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
			for _, id := range batch {
				f, ok := farmers[id]
				if !ok {
					continue
				}
				text, sms := faAssignedNotice(fa, f.Language)
				if err := s.refNotice(ctx, tx, q, id, "system", "system", "fa_assignment", ref, text, sms); err != nil {
					return err
				}
			}
			return nil
		})
		if err != nil {
			return err
		}
	}
	return nil
}

// onVisitLogged sends the farmer the visit's advice: a notice with every
// issue and remedy, and a short SMS linking to it.
func (s *Service) onVisitLogged(ctx context.Context, e events.VisitLogged) error {
	advice, err := s.ports.Visits.GetVisitAdvice(ctx, e.VisitID)
	if err != nil {
		if gone(ctx, err, "visit") {
			return nil
		}
		return err
	}
	f, err := s.farmerSummary(ctx, e.FarmerID)
	if err != nil {
		if gone(ctx, err, "farmer") {
			return nil
		}
		return err
	}
	text, sms := visitAdviceNotice(advice, f.Language)
	return s.inTx(ctx, func(tx pgx.Tx, q *store.Queries) error {
		return s.refNotice(ctx, tx, q, f.ID, "visit_advice", "fa", "visit", e.VisitID, text, sms)
	})
}

// refNotice creates a notice about a record plus its SMS delivery, unless the
// farmer already has a notice for that record.
func (s *Service) refNotice(ctx context.Context, tx pgx.Tx, q *store.Queries, farmerID uuid.UUID,
	kind, sender, refType string, refID uuid.UUID, text noticeText, sms message) error {
	row, err := q.InsertRefNotice(ctx, store.InsertRefNoticeParams{
		ID: ids.New(), FarmerID: farmerID, Kind: kind, Sender: sender,
		TitleTe: text.TitleTe, BodyTe: text.BodyTe, TitleEn: text.TitleEn, BodyEn: text.BodyEn,
		RefType: &refType, RefID: someUUID(refID),
	})
	if db.IsNoRows(err) {
		return nil // already sent
	}
	if err != nil {
		return apperr.Internalf("messaging: insert notice: %w", err)
	}
	if err := s.createDeliveries(ctx, tx, q, []deliverySpec{{
		NoticeID: row.ID, FarmerID: farmerID, Channel: ChannelSMS, Message: sms,
	}}); err != nil {
		return err
	}
	_, err = audit.Record(ctx, tx, audit.Entry{
		Action: "messaging.notice_sent", EntityType: "notice", EntityID: row.ID, FarmerID: farmerID,
		Meta: map[string]any{"kind": kind, "ref_type": refType, "ref_id": refID, "channels": []string{ChannelInApp, ChannelSMS}},
	})
	return err
}

func derefStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
