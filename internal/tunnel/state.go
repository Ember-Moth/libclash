package tunnel

import (
	"github.com/metacubex/mihomo/tunnel"
)

func QueryMode() string {
	return tunnel.Mode().String()
}

func SetMode(mode string) bool {
	nextMode, ok := tunnel.ModeMapping[mode]
	if !ok {
		return false
	}

	tunnel.SetMode(nextMode)
	return true
}
