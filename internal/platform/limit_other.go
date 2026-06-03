//go:build !linux

package platform

func ShouldBlockConnection() bool {
	return false
}
