package httpx

import (
	"errors"
	"net/http"
	"strings"

	"github.com/sapionic/orbit/backend/internal/platform/apperr"
)

// DefaultMaxBodyBytes is the request body cap when none is configured.
const DefaultMaxBodyBytes int64 = 2 << 20 // 2 MiB

// BodyLimit caps request bodies at max bytes, or at the limit in overrides
// for the request's path (exact path, or a "/prefix/*" key). A declared
// Content-Length over the cap is refused at once with 413; a body that turns
// out bigger while it is read fails the read with *http.MaxBytesError, which
// the error handlers turn into the same 413.
func BodyLimit(max int64, overrides map[string]int64) func(http.Handler) http.Handler {
	if max <= 0 {
		max = DefaultMaxBodyBytes
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Body == nil || r.Body == http.NoBody {
				next.ServeHTTP(w, r)
				return
			}
			limit := bodyLimitFor(r.URL.Path, max, overrides)
			if r.ContentLength > limit {
				WriteError(w, r, apperr.TooLarge(limit))
				return
			}
			r.Body = http.MaxBytesReader(w, r.Body, limit)
			next.ServeHTTP(w, r)
		})
	}
}

func bodyLimitFor(path string, def int64, overrides map[string]int64) int64 {
	if n, ok := overrides[path]; ok {
		return n
	}
	for k, n := range overrides {
		if prefix, ok := strings.CutSuffix(k, "/*"); ok && strings.HasPrefix(path, prefix+"/") {
			return n
		}
	}
	return def
}

// tooLarge converts a body-read failure caused by BodyLimit into 413.
func tooLarge(err error) (*apperr.Error, bool) {
	var mbe *http.MaxBytesError
	if errors.As(err, &mbe) {
		return apperr.TooLarge(mbe.Limit), true
	}
	return nil, false
}
