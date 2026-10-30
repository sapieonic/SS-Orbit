package farmers

import (
	"context"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/sapionic/orbit/backend/internal/farmers/store"
	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/audit"
	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/commands"
	"github.com/sapionic/orbit/backend/internal/platform/db"
	"github.com/sapionic/orbit/backend/internal/platform/phone"
	"github.com/sapionic/orbit/backend/internal/platform/territory"
)

// RecordConsent records consent the FA captured after an enrolment that had
// no valid OTP proof (FAR-04). The proof must be for this FA and the farmer's
// phone number; the consent rows are timed when the OTP was verified.
// Idempotent: the row IDs derive from the command.
func (s *Service) RecordConsent(ctx context.Context, p auth.Principal, cmd commands.Command, in RecordConsentPayload) (commands.Result, error) {
	ctx = auth.WithPrincipal(ctx, p)
	if p.Kind != auth.KindFA {
		return commands.Rejected(in.FarmerID, "only an FA can record consent"), nil
	}
	fields := map[string]string{}
	purposes, msg := cleanPurposes(in.Purposes)
	switch {
	case msg != "":
		fields["purposes"] = msg
	case len(purposes) == 0:
		fields["purposes"] = "required"
	}
	if strings.TrimSpace(in.NoticeVersion) == "" {
		fields["notice_version"] = "required"
	}
	if strings.TrimSpace(in.OTPProof) == "" {
		fields["otp_proof"] = "required"
	}
	if len(fields) > 0 {
		return result(in.FarmerID, commands.Result{}, apperr.ValidationFields(fields))
	}
	proof, err := s.deps.Tokens.VerifyConsentProof(in.OTPProof)
	if err != nil {
		return result(in.FarmerID, commands.Result{}, err)
	}
	if proof.FAID != p.ID {
		return commands.Rejected(in.FarmerID, "otp_proof: the consent OTP was verified by another FA"), nil
	}

	var res commands.Result
	err = s.inTx(ctx, func(q *store.Queries, tx pgx.Tx) error {
		f, err := s.lockFarmerForFA(ctx, q, p, in.FarmerID)
		if err != nil {
			return err
		}
		if proof.Phone != f.Phone {
			return apperr.Validation("otp_proof", "the consent OTP was sent to another phone number")
		}
		res = commands.Applied(f.ID)
		if _, err := q.GetConsent(ctx, consentID(cmd.ID, purposes[0])); err == nil {
			return nil // replay
		} else if !db.IsNoRows(err) {
			return apperr.Internalf("farmers: consent replay check: %w", err)
		}
		if err := s.insertFAConsents(ctx, q, p, cmd, f, purposes, in.NoticeVersion, in.AudioPlayed, proof); err != nil {
			return err
		}
		if _, err := audit.Record(ctx, tx, audit.Entry{
			Action: "farmers.consent_granted", EntityType: "farmer", EntityID: f.ID, FarmerID: f.ID,
			After: map[string]any{"purposes": purposes, "method": MethodFAOTP, "notice_version": in.NoticeVersion,
				"otp_verified_at": proof.VerifiedAt.UTC(), "phone": phone.Mask(proof.Phone)},
			Meta: map[string]any{"command_id": cmd.ID},
		}); err != nil {
			return err
		}
		return territory.Bump(ctx, tx, p.ID)
	})
	return result(in.FarmerID, res, err)
}
