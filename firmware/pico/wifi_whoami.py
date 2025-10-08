# wifi_whoami.py  (MicroPython on Pico W/2W)
import network
import time

ssid = "Drone"
password = "drone529!"

# Initialize the Wi-Fi interface
wlan = network.WLAN(network.STA_IF)
wlan.active(True)
wlan.connect(ssid, password)


print("Connecting to network", ssid, "...")

timeout = 20  # seconds
while not wlan.isconnected() and timeout > 0:
    print("Waiting for connection... (remaining:", timeout, "s)")
    time.sleep(1)
    timeout -= 1

if wlan.isconnected():
    print("✅ Connected!")
    print("IP address:", wlan.ifconfig()[0])
else:
    raise RuntimeError("❌ Failed to connect to Wi‑Fi SSID '%s' within 20s" % ssid)

def mac_to_str(mac): return ':'.join('%02x' % b for b in mac)
def auth_str(m): return {0:'OPEN',1:'WEP',2:'WPA-PSK',3:'WPA2-PSK',4:'WPA/WPA2-PSK'}.get(m, str(m))

def show_ap(ap):
    print("AP_IF active:", ap.active())
    if not ap.active(): return
    cfg = ap.config()  # dict on Pico W
    ssid = cfg.get('essid') or cfg.get('ssid')
    print("  SSID:", ssid)
    if 'channel' in cfg: print("  Channel:", cfg['channel'])
    if 'authmode' in cfg: print("  Security:", auth_str(cfg['authmode']))
    if 'mac' in cfg: print("  MAC:", mac_to_str(cfg['mac']))
    print("  IP:", ap.ifconfig())

def show_sta(sta):
    print("STA_IF active:", sta.active(), "connected:", sta.isconnected())
    print("  Status:", sta.status())
    try:
        print("  RSSI:", sta.status('rssi'))  # may not exist on some builds
    except Exception:
        pass
    if sta.isconnected():
        try:
            ssid = sta.config('essid') or sta.config('ssid')
            print("  Connected SSID:", ssid)
        except Exception:
            pass
        print("  IP:", sta.ifconfig())
    print("  Nearby networks:")
    try:
        for ssid,bssid,ch,rssi,auth,hidden in sta.scan():
            name = ssid.decode() if isinstance(ssid, bytes) else ssid
            bss = ':'.join('%02x' % b for b in bssid)
            print(f"   - {name:20s} ch={ch:2d} rssi={rssi:4d} dBm  sec={auth_str(auth)}  bssid={bss}")
    except Exception as e:
        print("   scan() not available:", e)

ap = network.WLAN(network.AP_IF)
sta = network.WLAN(network.STA_IF)
show_ap(ap)
show_sta(sta)
