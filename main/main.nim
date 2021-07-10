import nesper, nesper/[net_utils, events, tasks, esp/net/tcpip_adapter]
import asyncdispatch
import networking, dns, http, fs

const TAG: cstring = "main"

app_main:
  # Create default event loop that runs in background
  check: esp_event_loop_create_default()

  networkingStart()

  var info: tcpip_adapter_ip_info_t
  check: tcpip_adapter_get_ip_info(TCPIP_ADAPTER_IF_AP, addr(info))

  let ap_ip = toIpAddress(info.ip)
  logi TAG, "ip: %s", $ap_ip  

  let keys = readKeys()
  if keys.len == 0:
    wifiApStart()
    waitFor run_http_server() and run_dns_server(ap_ip)
  else:
    let key = keys[0]
    wifiStaStart(key.ssid, key.password)

  logi TAG, "Connection set"