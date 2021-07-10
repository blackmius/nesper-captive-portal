import nesper, nesper/[net_utils, nvs_utils, events, wifi, tasks]
import net

const
  TAG: cstring = "networking"
  GOT_IPV4_BIT* = EventBits_t(BIT(1))
  CONNECTED_BITS* = (GOT_IPV4_BIT)

var networkConnectEventGroup*: EventGroupHandle_t
var networkIpAddr*: IpAddress
var networkConnectionName*: cstring


proc ipReceivedHandler*(arg: pointer; event_base: esp_event_base_t; event_id: int32;
              event_data: pointer) {.cdecl.} =
  var event: ptr ip_event_got_ip_t = cast[ptr ip_event_got_ip_t](event_data)
  logi TAG, "event.ip_info.ip: %s", $(event.ip_info.ip)

  networkIpAddr = toIpAddress(event.ip_info.ip)
  # memcpy(addr(sIpAddr), addr(event.ip_info.ip), sizeof((sIpAddr)))
  logw TAG, "got event ip: %s", $networkIpAddr

proc onWifiDisconnect*(
    arg: pointer;
    event_base: esp_event_base_t;
    event_id: int32;
    event_data: pointer) {.cdecl.} =
  logi(TAG, "Wi-Fi disconnected, trying to reconnect...")
  check: esp_wifi_connect()

proc wifiStart() =
  let wcfg: wifi_init_config_t = wifi_init_config_default()
  discard esp_wifi_init(unsafeAddr(wcfg))

  WIFI_EVENT_STA_DISCONNECTED.eventRegister(onWifiDisconnect, nil)
  IP_EVENT_STA_GOT_IP.eventRegister(ipReceivedHandler, nil)

  check: esp_wifi_set_storage(WIFI_STORAGE_RAM)

proc wifiApStart*() =
  wifiStart()

  check: esp_wifi_set_mode(WIFI_MODE_APSTA)

  var wifi_config: wifi_config_t

  wifi_config.ap.max_connection = 10;

  check: esp_wifi_set_config(WIFI_IF_AP, addr(wifi_config))
  check: esp_wifi_start()

proc wifiConnect(): esp_err_t =
  if networkConnectEventGroup != nil:
    return ESP_ERR_INVALID_STATE

  networkConnectEventGroup = xEventGroupCreate()

  discard xEventGroupWaitBits(networkConnectEventGroup, CONNECTED_BITS, 1, 1, portMAX_DELAY)

proc wifiApConnect*(ssid: string, passport: string) =
  var wifi_config: wifi_config_t
  wifi_config.sta.ssid.setFromString(ssid)
  wifi_config.sta.password.setFromString(passport)

  logi(TAG, "Connecting to %s...", wifi_config.sta.ssid)
  check: esp_wifi_set_config(ESP_IF_WIFI_STA, addr(wifi_config))
  check: esp_wifi_connect()

  check: wifiConnect()

proc wifiStaStart*(ssid: string, passport: string) =
  var wifi_config: wifi_config_t
  wifi_config.sta.ssid.setFromString(ssid)
  wifi_config.sta.password.setFromString(passport)

  logi(TAG, "Connecting to %s...", wifi_config.sta.ssid)
  check: esp_wifi_set_mode(WIFI_MODE_STA)
  check: esp_wifi_set_config(ESP_IF_WIFI_STA, addr(wifi_config))
  check: esp_wifi_start()
  check: esp_wifi_connect()

  check: wifiConnect()

  networkConnectionName = ssid 

proc wifiStop*() =
  ##  tear down connection, release resources
  WIFI_EVENT_STA_DISCONNECTED.eventUnregister(onWifiDisconnect)
  IP_EVENT_STA_GOT_IP.eventUnregister(ipReceivedHandler)

  check: esp_wifiStop()
  check: esp_wifi_deinit()


proc networkingStart*(startNvs=true) =

  logi TAG, "staring networking"

  # Networking will generally utilize NVS for storing net info
  # so it's best to start it first
  if startNvs:
    initNvs()

  # Initialize TCP/IP network interface (should be called only once in application)
  when defined(ESP_IDF_V4_0):
    tcpip_adapter_init()
  else:
    check: esp_netif_init()

proc networkDisconnect*(): esp_err_t =
  if networkConnectEventGroup == nil:
    return ESP_ERR_INVALID_STATE

  vEventGroupDelete(networkConnectEventGroup)
  networkConnectEventGroup = nil
  wifiStop()
  logi TAG, "Disconnected from %s", networkConnectionName
  networkConnectionName = nil

  return ESP_OK