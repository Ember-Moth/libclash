//go:build !(android && cmfa)

package app

func updateSystemDNS(addr []string) {
}

func flushCacheWithDefaultResolver() {
}
