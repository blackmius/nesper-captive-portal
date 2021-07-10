import nesper, nesper/[net_utils, nvs_utils, events, wifi, tasks, esp/net/tcpip_adapter]
import asynchttpserver, net, asyncdispatch, asyncnet, strutils

const TAG: cstring = "main"

proc networkingStart(startNvs=true) =

  # Networking will generally utilize NVS for storing net info
  # so it's best to start it first
  if startNvs:
    initNvs()

  # Initialize TCP/IP network interface (should be called only once in application)
  when defined(ESP_IDF_V4_0):
    tcpip_adapter_init()
  else:
    check: esp_netif_init()

  # Create default event loop that runs in background
  check: esp_event_loop_create_default()

  let wcfg: wifi_init_config_t = wifi_init_config_default()
  discard esp_wifi_init(unsafeAddr(wcfg))

  check: esp_wifi_set_storage(WIFI_STORAGE_RAM)
  check: esp_wifi_set_mode(WIFI_MODE_AP)

  var wifi_config: wifi_config_t

  wifi_config.ap.max_connection = 10;

  check: esp_wifi_set_config(WIFI_IF_AP, addr(wifi_config))
  check: esp_wifi_start()

var setup_connection = true

proc run_http_server() {.async.} =
  logi TAG, "Starting http server on port 80"

  var server = newAsyncHttpServer()

  proc cb(req: Request) {.async.} =
    await req.respond(Http200, "HELLO FROM ESP32")
  
  server.listen Port(80)
  while setup_connection:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

proc run_udp_server(ip: IpAddress) {.async.} =
  logi TAG, "Starting dns server on port 53"

  let socket = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  socket.bindAddr(Port(53))

  let ip_bytes = chr(ip.address_v4[0]) & chr(ip.address_v4[1]) & chr(ip.address_v4[2]) & chr(ip.address_v4[3])

  while setup_connection:
    var msg = await socket.recvFrom(4096)
    let tipo = (msg.data[2].int shr 3) and 15
    var domain: string
    if tipo == 0:
      var
        ini = 12
        lon = msg.data[ini].int
      while lon != 0:
        domain &= msg.data[ini+1 .. ini+lon+1] & "."
        ini += lon+1
        lon = msg.data[ini].int
      if domain.len != 0:
        var packet = msg.data[0..1] & "\x81\x80" & msg.data[4..5] &
          "\x00\x01\x00\x00\x00\x00" & msg.data[12..^1] &
          "\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04" & ip_bytes
        logi TAG, "udp: %s -> %s", domain, $ip
        await socket.sendTo(msg.address, msg.port, packet)

app_main:
  networkingStart()

  var info: tcpip_adapter_ip_info_t
  check: tcpip_adapter_get_ip_info(TCPIP_ADAPTER_IF_AP, addr(info))

  let ap_ip = toIpAddress(info.ip)
  logi TAG, "ip: %s", $ap_ip  
  
  waitFor run_http_server() and run_udp_server(ap_ip)

  logi TAG, "Connection set"