#!/bin/sh
# Base configuration for the ZTE MF283+ on OpenWrt 25.12.x
#   - all four Ethernet ports bridged into LAN
#   - built-in LTE modem (QMI, /dev/cdc-wdm0) as the only WAN
#   - Google DNS on LAN and WAN
#   - 2.4 GHz Wi-Fi enabled
#
# Usage (on the router):
#   APN=internet sh configure.sh
#
# Environment overrides:
#   APN       (default: internet)
#   PDPTYPE   ipv4 | ipv6 | ipv4v6   (default: ipv4)
#   SSID      (default: MF283+)
#   COUNTRY   ISO 3166-1 alpha-2 regulatory domain (default: unchanged)
#   TXPOWER   dBm (default: unchanged)

set -e

APN="${APN:-internet}"
PDPTYPE="${PDPTYPE:-ipv4}"
SSID="${SSID:-MF283+}"

# --- LAN: put switch ports 0-3 (LAN1/WAN + LAN2-4) into VLAN 1 -------------
uci set network.@switch_vlan[0].ports='0 1 2 3 6t'
uci -q delete network.wan6 || true
uci set network.lan.dns='8.8.8.8 8.8.4.4'

# --- WAN: built-in LTE modem over QMI ---------------------------------------
uci set network.wan=interface
uci set network.wan.proto='qmi'
uci set network.wan.device='/dev/cdc-wdm0'
uci set network.wan.apn="$APN"
uci set network.wan.pdptype="$PDPTYPE"
uci set network.wan.peerdns='0'
uci set network.wan.dns='8.8.8.8 8.8.4.4'
uci set network.wan.auto='1'
uci commit network

# --- Firewall: WAN zone contains only the LTE interface ---------------------
uci set firewall.@zone[1].network='wan'
uci commit firewall

# --- Wi-Fi ------------------------------------------------------------------
uci -q delete wireless.radio0.disabled || true
uci set wireless.radio0.channel='1'
uci set wireless.radio0.htmode='HT40'
if [ -n "$COUNTRY" ]; then uci set wireless.radio0.country="$COUNTRY"; fi
if [ -n "$TXPOWER" ]; then uci set wireless.radio0.txpower="$TXPOWER"; fi
uci set wireless.default_radio0.ssid="$SSID"
uci commit wireless

/etc/init.d/network reload
/etc/init.d/firewall reload

echo "Done. Check the LTE link with: ifstatus wan_4"
