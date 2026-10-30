package push

import (
	"bytes"
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/sapionic/orbit/backend/internal/platform/logx"
)

func TestLogSenderRedacts(t *testing.T) {
	var buf bytes.Buffer
	_, err := NewLog(logx.NewWriter(&buf, "info", "json")).Send(context.Background(), Message{
		Token: "fcm-device-token", Title: "Code 5521", Body: "Open https://x.in/w?t=eyJsecret",
		Data: map[string]string{"link": "https://x.in/w?t=eyJsecret"},
	})
	require.NoError(t, err)
	assert.NotContains(t, buf.String(), "eyJsecret")
	assert.NotContains(t, buf.String(), "5521")
	assert.NotContains(t, buf.String(), "fcm-device-token")
}
