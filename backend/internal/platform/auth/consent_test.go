package auth

import (
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/clock"
)

func TestConsentProof(t *testing.T) {
	now := time.Date(2026, 10, 30, 10, 0, 0, 0, time.UTC)
	clk := clock.NewFake(now)
	tok := NewTokens("0123456789abcdef0123456789abcdef", "orbit", 15*time.Minute, clk)
	fa := uuid.New()

	s, err := tok.IssueConsentProof(ConsentProof{FAID: fa, Phone: "+919000000101", VerifiedAt: now}, 7*24*time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	got, err := tok.VerifyConsentProof(s)
	if err != nil || got.FAID != fa || got.Phone != "+919000000101" || !got.VerifiedAt.Equal(now) {
		t.Fatalf("round trip: %+v %v", got, err)
	}
	if _, err := tok.Verify(s); err == nil {
		t.Fatal("a consent proof must not work as an access token")
	}
	link, _, _ := tok.IssueLink(uuid.New(), "notice:x", time.Hour)
	if _, err := tok.VerifyConsentProof(link); err == nil {
		t.Fatal("a link token must not work as a consent proof")
	}
	expired := NewTokens("0123456789abcdef0123456789abcdef", "orbit", 15*time.Minute, clock.NewFake(now.Add(8*24*time.Hour)))
	if _, err := expired.VerifyConsentProof(s); err == nil {
		t.Fatal("expired proof accepted")
	}
}
