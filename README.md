![OpenWrt on ZTE MF283+](assets/banner.webp)

# OpenWrt on ZTE MF283+ (built-in LTE)

Installation and setup guide for official OpenWrt 25.12.6 on the ZTE MF283+ 4G router
(Ralink RT3352, 64 MiB RAM, 32 MiB SPI-NOR flash, built-in Cat 4 LTE modem on mini PCIe).
It covers flashing, the packages needed to bring up the built-in modem over QMI, a
4-port LAN + LTE WAN configuration, and signal / SMS / AT pages in LuCI.

The firmware images are unmodified official OpenWrt 25.12.6 builds (`ramips/rt305x`,
profile `zte_mf283plus`), available from
[downloads.openwrt.org](https://downloads.openwrt.org/releases/25.12.6/targets/ramips/rt305x/).

> **Unofficial guide. You do this at your own risk.** Flashing overwrites the vendor firmware.
> ZTE does not publish stock images for this carrier-branded router, so back up the flash
> first if you may ever want to go back (see Step 2, serial method).

## Hardware

| Component | Details |
|---|---|
| Model | ZTE MF283+ |
| SoC | Ralink RT3352, MIPS 24KEc @ 400 MHz |
| RAM | 64 MiB DDR2 (~57 MiB usable in Linux) |
| Flash | 32 MiB SPI-NOR (Macronix MX25L25635E); OpenWrt uses the first 16 MiB |
| Ethernet | 4x 10/100 Mbps (LAN1 doubles as WAN in the default image) |
| Wi-Fi | RT3352 built-in, 2.4 GHz 802.11b/g/n |
| LTE modem | ZTE P685M mini PCIe (firmware reports `ZM8630`), USB ID `19d2:1275` |
| Other | 1x USB 2.0, 2x RJ11 (phone, unused by OpenWrt) |
| Serial | 4-pin header near the buttons, 57600 8N1, 3.3 V |
| OpenWrt target | `ramips/rt305x`, profile `zte_mf283plus` |

### Switch ports

| Front label | Switch port | Default image | This guide |
|---|---|---|---|
| LAN1 / WAN | 0 | WAN (`eth0.2`) | LAN |
| LAN2 | 1 | LAN | LAN |
| LAN3 | 2 | LAN | LAN |
| LAN4 | 3 | LAN | LAN |
| CPU | 6t | tagged | tagged |

### Modem interfaces

| Device | Use |
|---|---|
| `/dev/cdc-wdm0` | QMI control (`uqmi`, `proto qmi`) |
| `wwan0` | LTE data (raw-IP) |
| `/dev/ttyUSB0` | Diagnostic, does not answer AT |
| `/dev/ttyUSB1` | AT commands |
| `/dev/ttyUSB2` | AT commands |

## Installation

### 1. Download the images

| File | SHA256 |
|---|---|
| `openwrt-25.12.6-ramips-rt305x-zte_mf283plus-initramfs-kernel.bin` | `dc90a58b3a1dd08cfef2c80f3a49987ad9e288794f7f495dac971406334743c2` |
| `openwrt-25.12.6-ramips-rt305x-zte_mf283plus-squashfs-sysupgrade.bin` | `a981fe4bb6f4d6cd7650e3e45bb3815ae03adacbb8258d16031740695d675d10` |

### 2. Flash OpenWrt

There are two ways in. Both need a PC with a TFTP server and an Ethernet cable.

#### Option A: TFTP recovery (no disassembly)

1. Set the PC's Ethernet adapter to the static IP `192.168.0.22/24`.
2. Copy the **sysupgrade** image to the TFTP server root and name it `root_uImage`.
3. With the router powered off, hold **Reset** and **WPS** together, power it on and keep
   holding for about 5 seconds, until the WWAN and Signal LEDs blink.
4. The bootloader (at `192.168.0.1`) fetches `root_uImage` and writes it to flash.
   The TFTP window opens about 5 seconds after power-on and stays open for about 10 seconds.
5. Wait about a minute for OpenWrt to boot.

This method does not back up the vendor firmware.

#### Option B: Serial console + initramfs (lets you back up the vendor firmware)

1. Open the case and connect a 3.3 V USB-UART adapter to the 4-pin header (GND, TX, RX only;
   pin 1 / VCC is the square pad). 57600 8N1.
   Prolific PL2303 and WCH CH340 adapters are known to produce garbage on this board;
   Silicon Labs CP210x and FTDI FT232 work.
2. Put the **initramfs** image in the TFTP server root under a short name, e.g. `firmware.bin`.
3. Power on and press `1` in the U-Boot menu ("Load system code to SDRAM via TFTP").
4. Enter the device IP (default `192.168.0.1`), the TFTP server IP (default `192.168.0.22`)
   and the file name. U-Boot saves these for next time.
5. OpenWrt boots in RAM. **Back up all MTD partitions now** (the `firmware` partition, `mtd3`,
   is the most important):

   ```sh
   for n in 0 1 2 3; do
     ssh root@192.168.1.1 "cat /dev/mtd$n" > mtd$n.bin
   done
   ```

6. Copy the sysupgrade image to the router and flash it:

   ```sh
   scp -O openwrt-25.12.6-ramips-rt305x-zte_mf283plus-squashfs-sysupgrade.bin root@192.168.1.1:/tmp/
   ssh root@192.168.1.1 "sysupgrade -n /tmp/openwrt-25.12.6-ramips-rt305x-zte_mf283plus-squashfs-sysupgrade.bin"
   ```

After flashing, OpenWrt is at `192.168.1.1`, user `root`, no password. Set one first.

### 3. Install the LTE packages

OpenWrt 25.12 uses `apk` instead of `opkg`. On a fresh install these modem packages are
already present: `kmod-usb-net-qmi-wwan`, `uqmi`, `kmod-usb-serial-option`,
`kmod-usb-serial-wwan`, `kmod-usb-wdm`, `wwan`.

Still needed:

| Package | Source | Purpose |
|---|---|---|
| `luci-proto-qmi` | OpenWrt `luci` feed | "QMI Cellular" protocol in LuCI |
| `picocom` | OpenWrt `packages` feed | Serial terminal for AT commands |
| `sms-tool` | OpenWrt `packages` feed | AT / SMS / USSD command-line tool |
| `comgt` | OpenWrt `packages` feed | `gcom`, required by 3ginfo-lite |
| `luci-app-3ginfo-lite` | [4IceG/luci-app-3ginfo-lite](https://github.com/4IceG/luci-app-3ginfo-lite/releases) | Signal / cell info page |
| `luci-app-sms-tool-js` | [4IceG/luci-app-sms-tool-js](https://github.com/4IceG/luci-app-sms-tool-js/releases) | SMS, USSD and AT command pages |

The router has no internet until the modem is configured, so either connect it to another
uplink, or download the `.apk` files on a PC and copy them over:

```sh
scp -O *.apk root@192.168.1.1:/tmp/
ssh root@192.168.1.1 "apk add --no-network --allow-untrusted /tmp/*.apk"
```

`--allow-untrusted` is needed offline because apk v3 trusts packages through the signed
repository index, which cannot be fetched without internet. Download official packages only
from `downloads.openwrt.org` over HTTPS. Once the LTE link is up you can use the normal path:

```sh
apk update
apk add luci-proto-qmi picocom sms-tool comgt
```

Versions tested: `luci-proto-qmi` 26.304.26398, `picocom` 3.1-r5, `sms-tool` 2025.08.23,
`comgt` 0.32-r37, `luci-app-3ginfo-lite` 1.0.77, `luci-app-sms-tool-js` 2.0.42.

### 4. Check the modem

```sh
uqmi -s -d /dev/cdc-wdm0 --get-imei
uqmi -s -d /dev/cdc-wdm0 --uim-get-sim-state
uqmi -s -d /dev/cdc-wdm0 --get-serving-system
uqmi -s -d /dev/cdc-wdm0 --get-signal-info
sms_tool -d /dev/ttyUSB1 at "ATI"
```

`uqmi --get-capabilities` crashes (segmentation fault) with this modem; the other calls work.

### 5. Configure LAN, LTE WAN and Wi-Fi

[`tools/configure.sh`](tools/configure.sh) applies the configuration below.
Copy it to the router and run it with your operator's APN:

```sh
scp -O tools/configure.sh root@192.168.1.1:/tmp/
ssh root@192.168.1.1 "APN=internet sh /tmp/configure.sh"
```

| Setting | Value |
|---|---|
| LAN | All 4 ports (switch VLAN 1: `0 1 2 3 6t`), `192.168.1.1/24` |
| WAN | `proto qmi`, `/dev/cdc-wdm0`, APN from `$APN`, `pdptype ipv4` |
| DNS | `8.8.8.8`, `8.8.4.4` on LAN and WAN (`peerdns 0`) |
| Firewall | `wan` zone covers only the LTE interface; `wan6` removed |
| Wi-Fi | Enabled, SSID `MF283+`, channel 1 |

On 25.12, `proto qmi` brings up `wan` and then creates a dynamic child interface `wan_4`
that runs DHCP on `wwan0`. Check it with `ifstatus wan_4`. Seeing both `wan` and `wan_4`
in LuCI is normal.

With HT40 configured, the radio still settles on 20 MHz on channel 1.

### 6. Optional: fixed TTL on forwarded traffic

The two nftables snippets in [`files/`](files) set the IPv4 TTL to 64 on all packets in the
`mangle_prerouting` and `mangle_postrouting` chains (the fw4 equivalent of
`iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64`). fw4 picks them up automatically:

```sh
scp -O -r files/usr root@192.168.1.1:/
ssh root@192.168.1.1 "
  printf '%s\n' \
    /usr/share/nftables.d/chain-post/mangle_postrouting/10-ttl64.nft \
    /usr/share/nftables.d/chain-post/mangle_prerouting/10-ttl64.nft >> /etc/sysupgrade.conf
  fw4 reload
  nft list ruleset | grep 'ttl set'
"
```

Listing them in `/etc/sysupgrade.conf` keeps them across firmware upgrades.

### 7. Signal, SMS and AT pages in LuCI

After installing `luci-app-3ginfo-lite` and `luci-app-sms-tool-js`, run
[`tools/setup-modem-ui.sh`](tools/setup-modem-ui.sh). It:

- points 3ginfo-lite at `/dev/ttyUSB1` and sms-tool at `/dev/ttyUSB2`, so the two apps do
  not fight over one port;
- creates `/etc/config/modemdefine` and patches the 3ginfo-lite rpcd ACL so the page can run
  `3ginfo.sh` with arguments and read `modemdefine` (without this the page shows
  "Exec permission denied"). The original ACL is saved to `/root/`.

```sh
scp -O tools/setup-modem-ui.sh root@192.168.1.1:/tmp/
ssh root@192.168.1.1 "COUNTRY_CODE=48 sh /tmp/setup-modem-ui.sh"
```

Replace `48` with your country calling code. The script restarts `rpcd`, which logs you out
of LuCI.

The pages are under **Modem** in LuCI:

| Page | Shows |
|---|---|
| Modem → 3ginfo-lite | Operator, technology and band, CSQ, RSSI, RSRP, RSRQ, SINR, cell ID |
| Modem → SMS Messages | Received / send SMS, USSD codes, AT commands |

3ginfo-lite reads signal and band data from this modem, but leaves the modem name, IMEI,
IMSI and ICCID fields empty. Use `uqmi` (Step 4) for those.

## Tested result

On OpenWrt 25.12.6 (kernel 6.12.112) the modem registered on LTE band 1 (2100 MHz) and the
`wan_4` interface got an IPv4 lease over `wwan0`; ping, DNS and HTTP through the LTE link
worked from the router. Overlay space after installing everything above: about 9 MiB free
of 9.8 MiB.

## Reverting to the vendor firmware

Use one of the two flashing methods again:

- **TFTP recovery:** serve your `mtd3` (`firmware`) backup as `root_uImage`.
- **Serial:** boot the initramfs image, copy your backup to `/tmp/firmware.bin` and run
  `mtd write /tmp/firmware.bin /dev/mtd3`.

## References

- [OpenWrt Wiki: ZTE MF283plus](https://openwrt.org/toh/zte/mf283plus)
- [OpenWrt Wiki: WWAN / 3G / 4G / LTE](https://openwrt.org/docs/guide-user/network/wan/wwan/start)
- [4IceG/luci-app-3ginfo-lite](https://github.com/4IceG/luci-app-3ginfo-lite)
- [4IceG/luci-app-sms-tool-js](https://github.com/4IceG/luci-app-sms-tool-js)

## License

This guide is licensed under [CC BY 4.0](LICENSE). The scripts in [`tools/`](tools) and the
files in [`files/`](files) are licensed under the [MIT License](LICENSE-tools).

The firmware is unmodified official OpenWrt 25.12.6, licensed under GPL-2.0. Source code:
[openwrt/openwrt @ v25.12.6](https://github.com/openwrt/openwrt/tree/v25.12.6).
