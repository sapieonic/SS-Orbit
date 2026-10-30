package sms

import (
	"bytes"
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

func TestLogSenderRedactsOutsideDev(t *testing.T) {
	var buf bytes.Buffer
	msg := Message{To: "+919848012345", Body: "482913 is your code. Open https://x.in/w?t=eyJsecret.tok.en", TemplateID: "otp"}
	_, err := NewLog(logx.NewWriter(&buf, "info", "json")).Send(context.Background(), msg)
	require.NoError(t, err)
	assert.NotContains(t, buf.String(), "482913")
	assert.NotContains(t, buf.String(), "eyJsecret")
	assert.NotContains(t, buf.String(), "9848012345")

	buf.Reset()
	_, err = NewDevLog(logx.NewWriter(&buf, "info", "json")).Send(context.Background(), msg)
	require.NoError(t, err)
	assert.Contains(t, buf.String(), "482913", "dev shows the code so developers can sign in")
}
