import nesper
import asynchttpserver, net, asyncdispatch, uri, marshal

import networking

const TAG = "http"
const FILE = """<title>ne1 module</title><body></body>"""

proc run_http_server*() {.async.} =
  logi TAG, "Starting http server on port 80"

  var server = newAsyncHttpServer()

  proc cb(req: Request) {.async.} =
    logi TAG, "%s %s", $req.reqMethod, $req.url
    if req.url.path == "/sta_list":
      let headers = newHttpHeaders([("Content-Type","application/json")])
      await req.respond(Http200, $$apRecords, headers)
    else:
      let headers = newHttpHeaders([("Content-Type","text/html; charset=utf-8")])
      await req.respond(Http200, FILE, headers)
  
  server.listen Port(80)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()