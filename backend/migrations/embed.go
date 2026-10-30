// Package migrations embeds the goose SQL migrations so binaries and tests can
// apply them without reading the filesystem. The SQL files are the schema source
// of truth for both goose and sqlc.
package migrations

import "embed"

// FS holds every *.sql migration in this directory.
//
//go:embed *.sql
var FS embed.FS
