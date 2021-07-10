import os, json, marshal

const
    BASE_PATH = "/"
    WIFI_KEYS_PATH = BASE_PATH / "wifi.json"

type WifiCredentials = tuple[ssid: string, password: string]

proc readKeys*(): seq[WifiCredentials] =
    if fileExists(WIFI_KEYS_PATH):
        let data = readFile(WIFI_KEYS_PATH)
        let arr = parseJson(data)
        return to(arr, seq[WifiCredentials])
    return @[]

proc writeKeys*(keys: seq[WifiCredentials]) =
    writeFile(WIFI_KEYS_PATH, $$keys)