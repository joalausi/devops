const express = require("express");
const os = require("os");
const client = require("prom-client");

const app = express();
const port = process.env.PORT || 3000;
const register = new client.Registry();

client.collectDefaultMetrics({ register, prefix: "sherlock_" });

const httpRequests = new client.Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "route", "status"],
  registers: [register]
});

const httpDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status"],
  buckets: [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
  registers: [register]
});

const customOperations = new client.Counter({
  name: "sherlock_custom_operations_total",
  help: "Custom application operation counter",
  registers: [register]
});

let requestCount = 0;

function log(level, message, fields = {}) {
  process.stdout.write(`${JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    service: "sherlock-backend",
    host: process.env.BACKEND_SERVER_NAME || os.hostname(),
    message,
    ...fields
  })}\n`);
}

app.use((req, res, next) => {
  const started = process.hrtime.bigint();
  res.on("finish", () => {
    const route = req.route?.path || req.path;
    const status = String(res.statusCode);
    const duration = Number(process.hrtime.bigint() - started) / 1e9;
    httpRequests.inc({ method: req.method, route, status });
    httpDuration.observe({ method: req.method, route, status }, duration);
    log(res.statusCode >= 500 ? "error" : "info", "request completed", {
      method: req.method,
      route,
      status: res.statusCode,
      duration_seconds: duration
    });
  });
  next();
});

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "sherlock-logs-backend",
    timestamp: new Date().toISOString()
  });
});

// Existing JSON endpoint is preserved for the frontend.
app.get("/metrics", (req, res) => {
  requestCount += 1;
  customOperations.inc();
  const cpus = os.cpus();
  res.json({
    backend_server: process.env.BACKEND_SERVER_NAME || "app-01",
    container_hostname: os.hostname(),
    platform: os.platform(),
    os_type: os.type(),
    os_release: os.release(),
    cpu_model: cpus.length > 0 ? cpus[0].model : "unknown",
    cpu_cores: cpus.length,
    memory_total_mb: Math.round(os.totalmem() / 1024 / 1024),
    memory_free_mb: Math.round(os.freemem() / 1024 / 1024),
    uptime_seconds: Math.round(os.uptime()),
    request_count: requestCount,
    timestamp: new Date().toISOString()
  });
});

app.get("/prometheus", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

app.get("/simulate-error", (req, res) => {
  log("error", "simulated application error", { error_type: "review_demo" });
  res.status(500).json({ error: "simulated error for monitoring demo" });
});

app.listen(port, "0.0.0.0", () => {
  log("info", "backend started", { port });
});
