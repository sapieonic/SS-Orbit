package masters

import (
	"context"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
	"github.com/sapionic/orbit/backend/internal/platform/db"
)

// IssueLabel returns an issue's English and Telugu names. Visits copies them
// onto the visit at log time so history survives later renames.
func (s *Service) IssueLabel(ctx context.Context, issueID uuid.UUID) (name, nameTe string, err error) {
	row, err := s.q.GetIssue(ctx, issueID)
	if db.IsNoRows(err) {
		return "", "", apperr.NotFound("issue")
	}
	if err != nil {
		return "", "", apperr.Internalf("masters: issue label: %w", err)
	}
	return row.Name, row.NameTe, nil
}

// StageLabel returns a crop stage's English and Telugu names.
func (s *Service) StageLabel(ctx context.Context, stageID uuid.UUID) (name, nameTe string, err error) {
	row, err := s.q.GetStage(ctx, stageID)
	if db.IsNoRows(err) {
		return "", "", apperr.NotFound("crop stage")
	}
	if err != nil {
		return "", "", apperr.Internalf("masters: stage label: %w", err)
	}
	return row.Name, row.NameTe, nil
}
