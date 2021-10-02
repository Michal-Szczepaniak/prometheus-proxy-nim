import asynchttpserver, asyncdispatch, urlly, sequtils

type
  Metric = tuple
    name, value, metricType: string
var metrics: seq[(string, Metric)]

func `[]`*(query: seq[(string, Metric)], key: string): Metric =
  for (k, v) in query:
    if k == key:
      return v

func `[]=`*(query: var seq[(string, Metric)], key: string, value: Metric) =
  for pair in query.mitems:
    if pair[0] == key:
      pair[1] = value
      return
  query.add((key, value))

proc getMetrics(metric: Metric): string =
  return "# TYPE " & metric.name & " " & metric.metricType & "\n" &
    metric.name & " " & metric.value & "\n"

proc getMetricsSummary(): string =
  var summary: string
  for (name, metric) in metrics:
    summary &= getMetrics(metric)
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
      if name != "" and value != "" and metricType != "":
        var metric: Metric = (name: name, value: value, metricType: metricType)
        metrics[name] = metric
        await req.respond(Http200, "", nil)
      else:
        await req.respond(Http400, "", nil)

proc main {.async.} =
  var server = newAsyncHttpServer()

  server.listen Port(8081)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

asyncCheck main()
runForever()