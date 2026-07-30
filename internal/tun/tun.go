package tun

import (
	"encoding/json"
	"io"
	"net"
	"net/netip"
	"strings"

	C "github.com/metacubex/mihomo/constant"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

// DefaultMTU is the value the Android client has always used (TUN_MTU in
// TunService.kt). It is only a fallback: a caller should pass the MTU its
// platform actually configured on the interface, because sing-tun sizes its
// per-packet buffers from this value.
const DefaultMTU = 9000

func Start(fd int, mtu int, stack, gateway, portal, dns string) (io.Closer, error) {
	if mtu <= 0 {
		mtu = DefaultMTU
	}

	log.Debugln("TUN: fd = %d, mtu = %d, stack = %s, gateway = %s, portal = %s, dns = %s", fd, mtu, stack, gateway, portal, dns)

	tunStack, ok := C.StackTypeMapping[strings.ToLower(stack)]
	if !ok {
		tunStack = C.TunSystem
	}

	var prefix4 []netip.Prefix
	var prefix6 []netip.Prefix
	for _, gatewayStr := range strings.Split(gateway, ",") { // "172.19.0.1/30" or "172.19.0.1/30,fdfe:dcba:9876::1/126"
		gatewayStr = strings.TrimSpace(gatewayStr)
		if len(gatewayStr) == 0 {
			continue
		}
		prefix, err := netip.ParsePrefix(gatewayStr)
		if err != nil {
			log.Errorln("TUN: %s", err.Error())
			return nil, err
		}

		if prefix.Addr().Is4() {
			prefix4 = append(prefix4, prefix)
		} else {
			prefix6 = append(prefix6, prefix)
		}
	}

	var dnsHijack []string
	for _, dnsStr := range strings.Split(dns, ",") { // "172.19.0.2" or "0.0.0.0"
		dnsStr = strings.TrimSpace(dnsStr)
		if len(dnsStr) == 0 {
			continue
		}
		dnsHijack = append(dnsHijack, net.JoinHostPort(dnsStr, "53"))
	}

	options := LC.Tun{
		Enable:              true,
		Device:              sing_tun.InterfaceName,
		Stack:               tunStack,
		DNSHijack:           dnsHijack,
		AutoRoute:           false, // the host owns the routing table
		AutoDetectInterface: false, // the host protects sockets itself
		Inet4Address:        prefix4,
		Inet6Address:        prefix6,
		MTU:                 uint32(mtu),
		FileDescriptor:      fd,
	}

	tunOptions, _ := json.Marshal(options)
	log.Debugln("%s", string(tunOptions))

	listener, err := sing_tun.New(options, tunnel.Tunnel)
	if err != nil {
		log.Errorln("TUN: %s", err.Error())
		return nil, err
	}

	return listener, nil
}
