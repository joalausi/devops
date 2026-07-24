function setText(id, value) {
  document.getElementById(id).textContent = value ?? "-";
}

function formatUptime(seconds) {
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);

  if (hours > 0) return `${hours}h ${minutes % 60}m`;
  if (minutes > 0) return `${minutes}m ${seconds % 60}s`;
  return `${seconds}s`;
}

async function loadDashboard() {
  try {
    const [serverInfoResponse, metricsResponse] = await Promise.all([
      fetch("/server-info.json", { cache: "no-store" }),
      fetch("/api/metrics", { cache: "no-store" })
    ]);

    const serverInfo = await serverInfoResponse.json();
    const metrics = await metricsResponse.json();

    setText("web-server", serverInfo.web_server);
    setText("backend-server", metrics.backend_server);
    setText("request-count", metrics.request_count);
    setText("uptime", formatUptime(metrics.uptime_seconds));

    setText("container-hostname", metrics.container_hostname);
    setText("os", `${metrics.os_type} ${metrics.os_release}`);
    setText("cpu", metrics.cpu_model);
    setText("cpu-cores", metrics.cpu_cores);
    setText("memory-total", `${metrics.memory_total_mb} MB`);
    setText("memory-free", `${metrics.memory_free_mb} MB`);
    setText("timestamp", metrics.timestamp);

    setText("raw", JSON.stringify({ serverInfo, metrics }, null, 2));
  } catch (error) {
    setText("web-server", "error");
    setText("backend-server", "error");
    setText("raw", error.message);
  }
}

loadDashboard();
setInterval(loadDashboard, 5000);