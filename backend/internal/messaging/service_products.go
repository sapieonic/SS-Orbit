package messaging

import (
	"context"
	"errors"
	"strings"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
)

// checkProductMentions refuses an advisory whose text names an active product
// or salt while names_product is false. names_product decides Agronomy
// approval and the (promotional) SMS template, so it cannot rest on a
// checkbox alone. The flag stays for what the scan cannot see (audio, image):
// set, it is always honoured.
func (s *Service) checkProductMentions(ctx context.Context, namesProduct bool, texts ...*string) error {
	if namesProduct {
		return nil
	}
	if s.ports.Masters == nil {
		return apperr.Internalf("messaging: %w", errors.New("masters port not wired"))
	}
	terms, err := s.ports.Masters.ProductTerms(ctx)
	if err != nil {
		return apperr.Internalf("messaging: product terms: %w", err)
	}
	if term, ok := mentionedTerm(terms, texts...); ok {
		return apperr.Validation("names_product",
			`the text mentions the product "`+term+`"; mark the advisory as naming a product so Agronomy approves it`)
	}
	return nil
}

// mentionedTerm returns the first term that appears in any text, compared
// case-insensitively as a substring. Terms are lower-cased by the provider;
// they are lowered again here so a mixed-case term still matches.
func mentionedTerm(terms []string, texts ...*string) (string, bool) {
	lowered := make([]string, 0, len(texts))
	for _, t := range texts {
		if t != nil && *t != "" {
			lowered = append(lowered, strings.ToLower(*t))
		}
	}
	for _, term := range terms {
		term = strings.ToLower(strings.TrimSpace(term))
		if term == "" {
			continue
		}
		for _, text := range lowered {
			if strings.Contains(text, term) {
				return term, true
			}
		}
	}
	return "", false
}
