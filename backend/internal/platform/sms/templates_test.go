package sms

import (
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// DLT registers one template per wording and language: two different texts
// must never share an ID, and every ID must look like a DLT ID.
func TestEveryWordingHasItsOwnDLTID(t *testing.T) {
	idRe := regexp.MustCompile(`^[0-9]{19}$`)
	textByID := map[string]string{}
	idByText := map[string]string{}
	keys := map[string]bool{}
	for _, tpl := range All() {
		require.Regexp(t, idRe, tpl.ID, "%s/%s: DLT IDs are 19 digits", tpl.Key, tpl.Lang)
		require.Contains(t, []string{"te", "en"}, tpl.Lang)
		if prev, ok := textByID[tpl.ID]; ok && prev != tpl.Text {
			t.Errorf("DLT ID %s is used by two wordings:\n  %q\n  %q", tpl.ID, prev, tpl.Text)
		}
		if prev, ok := idByText[tpl.Text]; ok && prev != tpl.ID {
			t.Errorf("wording %q has two IDs: %s, %s", tpl.Text, prev, tpl.ID)
		}
		textByID[tpl.ID], idByText[tpl.Text] = tpl.Text, tpl.ID
		keys[tpl.Key+"/"+tpl.Lang] = true
		assert.True(t, IsPlaceholder(tpl.ID), "replace this check when real DLT IDs arrive")
	}
	assert.Len(t, keys, len(All()), "key+language is unique")
}

// Callers fill one set of variables whatever the language, so Telugu may leave
// one out (to fit one SMS part) but never needs one English lacks.
func TestBothLanguagesUseTheSameVariables(t *testing.T) {
	for _, p := range []Pair{LoginOTP, LoginOTPRetriever, ConsentOTP, AdvisoryService, AdvisoryPromo,
		NoticeLink, Welcome, FAAssigned, VisitIssues, VisitNoIssues} {
		assert.Subset(t, p.En.Vars(), p.Te.Vars(), p.Te.Key)
		assert.Equal(t, p.Te.Key, p.En.Key)
	}
}

func TestRender(t *testing.T) {
	assert.Equal(t, "Hello Ravi, you are now registered with Orbit. You will get crop advice in the app and by SMS.",
		Welcome.En.Render(map[string]string{"name": "Ravi"}))
	assert.Equal(t, "Hello, you are now registered with Orbit. You will get crop advice in the app and by SMS.",
		Welcome.En.Render(map[string]string{"name": ""}), "an empty variable drops its leading space")

	got := AdvisoryService.Te.Render(map[string]string{"title": "వరి పంటకు దోమ పోటు నివారణ కోసం ముఖ్యమైన సలహా ఇది"})
	assert.Contains(t, got, LinkVar, "{link} is filled at send time")
	title := []rune(got[:strings.Index(got, ". ")])
	assert.Len(t, title, 30, "title capped at 30 runes")
	assert.Equal(t, '…', title[29])
}

// The Telugu sign-in code in Retriever format is one Unicode SMS part, and the
// app hash ends the message (SMS Retriever requirement).
func TestLoginOTPRetrieverFormat(t *testing.T) {
	for _, tpl := range []Template{LoginOTPRetriever.Te, LoginOTPRetriever.En} {
		got := tpl.Render(map[string]string{"code": "482913", "minutes": "5", "app_hash": "FA+9qCX9VSu"})
		assert.Regexp(t, `^<#> 482913 `, got)
		assert.Regexp(t, `\nFA\+9qCX9VSu$`, got)
	}
	te := LoginOTPRetriever.Te.Render(map[string]string{"code": "482913", "minutes": "5", "app_hash": "FA+9qCX9VSu"})
	assert.LessOrEqual(t, len([]rune(te)), 70, "one Unicode SMS part")
}
