import nesper, net, asyncnet, asyncdispatch, strutils

const TAG: cstring = "dns"

proc run_dns_server*(ip: IpAddress) {.async.} =
  logi TAG, "Starting dns server on port 53"

  let socket = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  socket.bindAddr(Port(53))

  let ip_bytes = chr(ip.address_v4[0]) & chr(ip.address_v4[1]) & chr(ip.address_v4[2]) & chr(ip.address_v4[3])

  while true:
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
        logi TAG, "%s -> %s", domain, $ip
        await socket.sendTo(msg.address, msg.port, packet)