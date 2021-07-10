import nesper, asynchttpserver, net, asyncdispatch, uri

const TAG: cstring = "http"

proc run_http_server*() {.async.} =
  logi TAG, "Starting http server on port 80"

  var server = newAsyncHttpServer()

  proc cb(req: Request) {.async.} =
    logi TAG, "%s %s", $req.reqMethod, $req.url
    await req.respond(Http200, "HELLO FROM ESP32")
  
  server.listen Port(80)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()