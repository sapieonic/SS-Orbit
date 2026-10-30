package messaging

import "github.com/sapionic/orbit/backend/internal/platform/commands"

// Sync commands owned by messaging (CONVENTIONS section 6).
func (m *Module) registerCommands(reg *commands.Registry) {
	reg.Register("AckAlert", commands.Typed(m.svc.ackAlert))
}
