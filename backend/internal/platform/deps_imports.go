package platform

// Blank imports pin third-party dependencies that module code is expected to
// use but that platform code does not import directly, so `go mod tidy` keeps
// them in go.mod and module agents never need to edit go.mod.
import (
	_ "github.com/oapi-codegen/runtime"       // used by oapi-codegen generated api.gen.go
	_ "github.com/oapi-codegen/runtime/types" // openapi_types.UUID / Date in generated models
	_ "github.com/riverqueue/river/rivertype" // job rows / insert results in module workers
)
