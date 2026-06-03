//go:build android && cmfa

package app

import "github.com/metacubex/mihomo/dns"

func updateSystemDNS(addr []string) {
	dns.UpdateSystemDNS(addr)
}

func flushCacheWithDefaultResolver() {
	dns.FlushCacheWithDefaultResolver()
}
