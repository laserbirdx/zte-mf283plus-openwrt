#!/bin/sh
# Configure luci-app-3ginfo-lite and luci-app-sms-tool-js for the
# ZTE MF283+ built-in modem (ZM8630, USB 19d2:1275).
#
# AT ports exposed by the modem:
#   /dev/ttyUSB0  - no AT response (diagnostic)
#   /dev/ttyUSB1  - AT  -> used by 3ginfo-lite
#   /dev/ttyUSB2  - AT  -> used by sms-tool (SMS / USSD / AT tab)
# Splitting the two apps across ports keeps them from colliding.
#
# Usage (on the router, after installing the packages):
#   COUNTRY_CODE=48 sh setup-modem-ui.sh

set -e

INFO_PORT="${INFO_PORT:-/dev/ttyUSB1}"
SMS_PORT="${SMS_PORT:-/dev/ttyUSB2}"

# --- 3ginfo-lite --------------------------------------------------------------
uci set 3ginfo.@3ginfo[0].device="$INFO_PORT"
uci set 3ginfo.@3ginfo[0].network='wan'
uci commit 3ginfo

# The LuCI view reads this config; create it so the rpcd ACL check succeeds.
touch /etc/config/modemdefine

# rpcd ACL fix: the view calls 3ginfo.sh with arguments and reads the
# modemdefine config, neither of which the stock ACL allows.
ACL=/usr/share/rpcd/acl.d/luci-app-3ginfo-lite.json
[ -f /root/luci-app-3ginfo-lite.json.orig ] || cp "$ACL" /root/luci-app-3ginfo-lite.json.orig
grep -q '3ginfo.sh \*' "$ACL" || \
  sed -i 's|"/usr/share/3ginfo-lite/3ginfo.sh": \[ "exec" \],|&\n\t\t\t\t"/usr/share/3ginfo-lite/3ginfo.sh *": [ "exec" ],|' "$ACL"
sed -i 's|"uci": \[ "3ginfo" \]|"uci": [ "3ginfo", "modemdefine" ]|' "$ACL"
jsonfilter -i "$ACL" -e '@' >/dev/null

# --- sms-tool-js --------------------------------------------------------------
for o in readport sendport ussdport atport; do
  uci set sms_tool_js.@sms_tool_js[0].$o="$SMS_PORT"
done
if [ -n "$COUNTRY_CODE" ]; then
  uci set sms_tool_js.@sms_tool_js[0].pnumber="$COUNTRY_CODE"
fi
uci commit sms_tool_js

/etc/init.d/rpcd restart
echo "Done. Log in to LuCI again (rpcd restart ends existing sessions)."
