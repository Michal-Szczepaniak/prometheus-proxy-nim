import asynchttpserver, asyncdispatch, urlly

type
  Metric = tuple
    name, value, metricType, client: string
var metrics: seq[(string, (string, Metric))]

func `[]`*(query: seq[(string, (string, Metric))], key: string): (string, Metric) =
  for (k, v) in query:
    if k == key:
      return v

func `[]=`*(query: var seq[(string, (string, Metric))], key: string, value: (string, Metric)) =
  for pair in query.mitems:
    if pair[0] == key:
      pair[1] = value
      return
  query.add((key, value))

proc getMetrics(hostname: string, metric: Metric): string =
  return "# TYPE " & metric.name & " " & metric.metricType & "\n" &
    metric.name & "{hostname=\"" & hostname & "\",client=\"" & metric.client & "\"} " & metric.value & "\n"

proc getMetricsSummary(): string =
  var summary: string
  for (name, value) in metrics:
    summary &= getMetrics(value[0], value[1])
  return summary

proc cb(req: Request) {.async,gcsafe.} =
  let headers = {"Content-type": "text/plain; charset=utf-8"}
  case req.url.path:
    of "/":
      await req.respond(Http200, "Hello prometheus proxy", headers.newHttpHeaders())
    of "/metrics":
      await req.respond(Http200, getMetricsSummary(), headers.newHttpHeaders())
    of "/addMetrics":
      let
        query = parseUrl("?" & req.url.query).query
        name = query["name"]
        value = query["value"]
        metricType = query["metricType"]
        client = query["client"]
      if name != "" and value != "" and metricType != "":
        var metric: Metric = (name: name, value: value, metricType: metricType, client: client)
        metrics[name] = (req.hostname, metric)
        await req.respond(Http200, "", nil)
      else:
        await req.respond(Http400, "", nil)

proc main {.async.} =
  var server = newAsyncHttpServer()

  server.listen Port(9100)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

asyncCheck main()
runForever()