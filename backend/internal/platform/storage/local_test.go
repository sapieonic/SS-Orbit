package storage

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLocalPresignedRoundTrip(t *testing.T) {
	r := chi.NewRouter()
	srv := httptest.NewServer(r)
	defer srv.Close()
	l, err := NewLocal(t.TempDir(), srv.URL, []byte("k"), nil)
	require.NoError(t, err)
	l.Mount(r)
	ctx := context.Background()

	put, err := l.PresignPut(ctx, "visits/v1/p1.jpg", "image/jpeg", time.Minute)
	require.NoError(t, err)
	req, _ := http.NewRequest(http.MethodPut, put.URL, strings.NewReader("jpegdata"))
	req.Header.Set("Content-Type", "image/jpeg")
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)

	ok, err := l.Exists(ctx, "visits/v1/p1.jpg")
	require.NoError(t, err)
	assert.True(t, ok)

	get, err := l.PresignGet(ctx, "visits/v1/p1.jpg", time.Minute)
	require.NoError(t, err)
	resp, err = http.Get(get)
	require.NoError(t, err)
	body, _ := io.ReadAll(resp.Body)
	assert.Equal(t, "jpegdata", string(body))

	// Wrong content type invalidates the PUT signature.
	req, _ = http.NewRequest(http.MethodPut, put.URL, strings.NewReader("x"))
	req.Header.Set("Content-Type", "text/html")
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	assert.Equal(t, http.StatusForbidden, resp.StatusCode)

	// A GET URL cannot be used to PUT.
	req, _ = http.NewRequest(http.MethodPut, get, strings.NewReader("x"))
	resp, err = http.DefaultClient.Do(req)
	require.NoError(t, err)
	assert.Equal(t, http.StatusForbidden, resp.StatusCode)
}

func TestValidKey(t *testing.T) {
	assert.True(t, ValidKey("a/b/c.jpg"))
	for _, k := range []string{"", "/abs", "a/../b", "a//b", "a\\b", "./a"} {
		assert.False(t, ValidKey(k), k)
	}
}
