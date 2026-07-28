const http = require("http");

const port = Number(process.env.PORT || 8080);
const webhookUrl = process.env.DISCORD_WEBHOOK_URL || "";

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        reject(new Error("request body exceeds 1 MiB"));
        req.destroy();
      }
    });
    req.on("end", () => {
      try {
        resolve(JSON.parse(body || "{}"));
      } catch (error) {
        reject(new Error(`invalid JSON: ${error.message}`));
      }
    });
    req.on("error", reject);
  });
}

function formatAlert(payload) {
  const status = String(payload.status || "firing").toUpperCase();
  const alerts = Array.isArray(payload.alerts) ? payload.alerts : [];
  const lines = alerts.slice(0, 8).map((alert) => {
    const labels = alert.labels || {};
    const annotations = alert.annotations || {};
    const name = labels.alertname || payload.commonLabels?.alertname || "Monitoring alert";
    const instance = labels.instance ? ` on ${labels.instance}` : "";
    const summary = annotations.summary || annotations.description || "Condition matched";
    return `• ${name}${instance}: ${summary}`;
  });

  if (lines.length === 0) {
    lines.push(payload.commonAnnotations?.summary || "Monitoring notification received");
  }

  return [`**Sherlock Logs — ${status}**`, ...lines].join("\n").slice(0, 1900);
}

async function sendDiscord(message) {
  if (!webhookUrl) {
    console.log("DISCORD_WEBHOOK_URL is not set; notification acknowledged locally.");
    return;
  }

  const response = await fetch(webhookUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ content: message, allowed_mentions: { parse: [] } })
  });

  if (!response.ok) {
    throw new Error(`Discord returned HTTP ${response.status}`);
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ status: "ok", discord_configured: Boolean(webhookUrl) }));
    return;
  }

  if (req.method !== "POST" || req.url !== "/alertmanager") {
    res.writeHead(404);
    res.end();
    return;
  }

  try {
    const payload = await readJson(req);
    await sendDiscord(formatAlert(payload));
    res.writeHead(204);
    res.end();
  } catch (error) {
    console.error(error.message);
    res.writeHead(502, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: error.message }));
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Notification relay listening on port ${port}`);
});
