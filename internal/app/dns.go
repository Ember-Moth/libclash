package app

import "strings"

func NotifyDnsChanged(dnsList string) {
	var addr []string
	if len(dnsList) > 0 {
		addr = strings.Split(dnsList, ",")
	}

	updateSystemDNS(addr)
	flushCacheWithDefaultResolver()
}
