// Command devtoken mints an access token for local testing with curl. It
// refuses to run unless ORBIT_ENV=dev. The subject does not need to exist in
// the database for routes that only check the token.
//
//	go run ./cmd/devtoken -kind ho -role admin
//	go run ./cmd/devtoken -kind fa -id 0192...
//	go run ./cmd/devtoken -kind farmer
//	curl -H "Authorization: Bearer $(go run ./cmd/devtoken -kind ho -role ops)" localhost:8080/v1/admin/audit
package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/sapionic/orbit/backend/internal/platform/auth"
	"github.com/sapionic/orbit/backend/internal/platform/config"
	"github.com/sapionic/orbit/backend/internal/platform/ids"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "devtoken:", err)
		os.Exit(1)
	}
}

func run() error {
	kind := flag.String("kind", "ho", "token kind: ho | fa | farmer | web")
	role := flag.String("role", "admin", "HO role: admin | agronomy | finance | ops")
	id := flag.String("id", "", "subject UUID (default: random)")
	districts := flag.String("districts", "", "comma-separated district UUIDs (HO area scope)")
	device := flag.String("device", "", "device UUID (fa/farmer; default: random)")
	purpose := flag.String("purpose", "dev", "web link purpose (kind=web)")
	ttl := flag.Duration("ttl", 12*time.Hour, "token lifetime (dev convenience; real access tokens use ACCESS_TOKEN_TTL)")
	flag.Parse()

	cfg, err := config.Load()
	if err != nil {
		return err
	}
	if !cfg.IsDev() {
		return fmt.Errorf("refusing to mint tokens outside ORBIT_ENV=dev")
	}
	p := auth.Principal{Kind: auth.Kind(*kind), ID: ids.New(), SessionID: ids.New()}
	if *id != "" {
		if p.ID, err = uuid.Parse(*id); err != nil {
			return fmt.Errorf("-id: %w", err)
		}
	}
	tokens := auth.NewTokens(cfg.JWTSecret, cfg.JWTIssuer, *ttl, nil)
	switch p.Kind {
	case auth.KindHO:
		p.Role = auth.Role(*role)
		for _, s := range strings.Split(*districts, ",") {
			if s = strings.TrimSpace(s); s == "" {
				continue
			}
			d, err := uuid.Parse(s)
			if err != nil {
				return fmt.Errorf("-districts: %w", err)
			}
			p.DistrictIDs = append(p.DistrictIDs, d)
		}
	case auth.KindFA, auth.KindFarmer:
		p.DeviceID = ids.New()
		if *device != "" {
			if p.DeviceID, err = uuid.Parse(*device); err != nil {
				return fmt.Errorf("-device: %w", err)
			}
		}
	case auth.KindWeb:
		tok, _, err := tokens.IssueLink(p.ID, *purpose, *ttl)
		if err != nil {
			return err
		}
		fmt.Println(tok)
		return nil
	default:
		return fmt.Errorf("unknown -kind %q", *kind)
	}
	tok, _, err := tokens.IssueAccess(p)
	if err != nil {
		return err
	}
	fmt.Println(tok)
	return nil
}
