package storage

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/sapionic/orbit/backend/internal/platform/clock"
)

// DevFilesPrefix is the route prefix Local serves files under.
const DevFilesPrefix = "/dev/files/"

// Local is a disk-backed Storage for development. Its presigned URLs point at
// the API itself; mount Handler() at /dev/files/* (app does this in dev).
type Local struct {
	dir     string
	baseURL string
	key     []byte
	clock   clock.Clock
}

// NewLocal stores files under dir and signs URLs rooted at publicBaseURL.
func NewLocal(dir, publicBaseURL string, signingKey []byte, clk clock.Clock) (*Local, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, fmt.Errorf("storage: %w", err)
	}
	if clk == nil {
		clk = clock.System()
	}
	return &Local{dir: dir, baseURL: strings.TrimRight(publicBaseURL, "/"), key: signingKey, clock: clk}, nil
}

func (l *Local) path(key string) string { return filepath.Join(l.dir, filepath.FromSlash(key)) }

func (l *Local) sign(method, key string, exp int64, contentType string) string {
	m := hmac.New(sha256.New, l.key)
	fmt.Fprintf(m, "%s\n%s\n%d\n%s", method, key, exp, contentType)
	return hex.EncodeToString(m.Sum(nil))
}

func (l *Local) url(method, key string, ttl time.Duration, contentType string) (string, time.Time) {
	exp := l.clock.Now().Add(ttl)
	q := url.Values{}
	q.Set("exp", strconv.FormatInt(exp.Unix(), 10))
	q.Set("sig", l.sign(method, key, exp.Unix(), contentType))
	return l.baseURL + DevFilesPrefix + key + "?" + q.Encode(), exp
}

// PresignPut implements Storage.
func (l *Local) PresignPut(_ context.Context, key, contentType string, ttl time.Duration) (Presigned, error) {
	if !ValidKey(key) {
		return Presigned{}, fmt.Errorf("storage: invalid key %q", key)
	}
	u, exp := l.url(http.MethodPut, key, ttl, contentType)
	return Presigned{URL: u, Method: http.MethodPut, Headers: map[string]string{"Content-Type": contentType}, ExpiresAt: exp}, nil
}

// PresignGet implements Storage.
func (l *Local) PresignGet(_ context.Context, key string, ttl time.Duration) (string, error) {
	if !ValidKey(key) {
		return "", fmt.Errorf("storage: invalid key %q", key)
	}
	u, _ := l.url(http.MethodGet, key, ttl, "")
	return u, nil
}

// Exists implements Storage.
func (l *Local) Exists(_ context.Context, key string) (bool, error) {
	if !ValidKey(key) {
		return false, fmt.Errorf("storage: invalid key %q", key)
	}
	_, err := os.Stat(l.path(key))
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	return err == nil, err
}

// Put implements Storage.
func (l *Local) Put(_ context.Context, key, _ string, r io.Reader) error {
	if !ValidKey(key) {
		return fmt.Errorf("storage: invalid key %q", key)
	}
	p := l.path(key)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(p), ".upload-*")
	if err != nil {
		return err
	}
	if _, err := io.Copy(tmp, r); err != nil {
		tmp.Close()
		os.Remove(tmp.Name())
		return err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmp.Name())
		return err
	}
	return os.Rename(tmp.Name(), p)
}

// Open implements Storage.
func (l *Local) Open(_ context.Context, key string) (io.ReadCloser, error) {
	if !ValidKey(key) {
		return nil, fmt.Errorf("storage: invalid key %q", key)
	}
	f, err := os.Open(l.path(key))
	if errors.Is(err, os.ErrNotExist) {
		return nil, ErrNotFound
	}
	return f, err
}

// maxDevUpload caps dev uploads (photos, audio).
const maxDevUpload = 25 << 20

// Mount registers GET/PUT /dev/files/* on r. Requests must carry a valid,
// unexpired signature from PresignGet / PresignPut.
func (l *Local) Mount(r chi.Router) {
	r.Get(DevFilesPrefix+"*", l.serve)
	r.Put(DevFilesPrefix+"*", l.serve)
}

func (l *Local) serve(w http.ResponseWriter, r *http.Request) {
	key := chi.URLParam(r, "*")
	exp, err := strconv.ParseInt(r.URL.Query().Get("exp"), 10, 64)
	if !ValidKey(key) || err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	ct := ""
	if r.Method == http.MethodPut {
		ct = r.Header.Get("Content-Type")
	}
	want := l.sign(r.Method, key, exp, ct)
	if !hmac.Equal([]byte(want), []byte(r.URL.Query().Get("sig"))) || l.clock.Now().Unix() > exp {
		http.Error(w, "invalid or expired signature", http.StatusForbidden)
		return
	}
	switch r.Method {
	case http.MethodPut:
		if err := l.Put(r.Context(), key, ct, http.MaxBytesReader(w, r.Body, maxDevUpload)); err != nil {
			http.Error(w, "upload failed", http.StatusBadRequest)
			return
		}
		w.WriteHeader(http.StatusOK)
	default:
		http.ServeFile(w, r, l.path(key))
	}
}
