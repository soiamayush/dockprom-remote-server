# dockprom-remote-server

Remote monitoring agent stack for machines monitored by the central
[`dockprom`](../dockprom) server.

The same repo is intended to work for:

- Windows / CPU-only testing machines
- Linux CPU machines
- Linux NVIDIA GPU machines

The priority path is Linux + GPU, but the default mode is safe for CPU-only and
Windows Docker Desktop so the stack does not fail when NVIDIA devices are not
available.

## Architecture

```text
central dockprom machine                         remote machine
────────────────────────                         ─────────────────────────────
Grafana dashboards                               dockprom-remote-server
Prometheus                                       - otel-host-collector (default)
otel-collector :4318  ◀── OTLP metrics ────────  - nodeexporter (Linux profile)
                                                 - cadvisor (Linux profile)
Prometheus scrapes :9100/:8080 if configured ◀── - otel-gpu-collector (GPU profile)
```

Use one stable `SERVER_ID` per physical/VM machine. This is what Grafana uses to
separate servers.

Examples:

```env
SERVER_ID=linux-main
SERVER_ID=gpu-server-1
SERVER_ID=windows-test-1
```

## Modes

### Default: CPU-Safe Mode

Runs:

- `otel-host-collector`

This mode does **not** require Linux host mounts or NVIDIA devices:

```bash
docker compose up -d
```

Use this for:

- Windows Docker Desktop testing
- CPU-only machines
- quick smoke tests

Note: on Windows Docker Desktop this reports metrics from the Docker
environment/VM, not native Windows host internals. For real Windows host metrics,
install a native Windows exporter separately and scrape it from central
Prometheus.

If you also want the existing Docker Host / Docker Containers dashboards to stop
showing `N/A` during Windows testing, start the Linux exporter profile too:

```powershell
docker compose --profile linux up -d
```

Those `nodeexporter` / `cadvisor` metrics come from Docker Desktop's Linux VM,
not from native Windows itself.

### Linux Host Mode

Runs:

- `otel-host-collector`
- `nodeexporter`
- `cadvisor`

Use this on Linux machines:

```bash
docker compose --profile linux up -d
```

### Linux NVIDIA GPU Mode

Runs:

- `otel-host-collector`
- `nodeexporter`
- `cadvisor`
- `otel-gpu-collector`

Use this on Linux NVIDIA machines:

```bash
NVIDIA_ML_LIB_PATH=/usr/lib/x86_64-linux-gnu/libnvidia-ml.so.550.90.07 \
docker compose --profile linux --profile gpu up -d
```

The helper script `./start.sh` auto-detects this when possible.

## Setup

### 1. Configure `.env`

```bash
cp .env.example .env
```

Edit `.env`:

```env
MAIN_SERVER_IP=<central-dockprom-ip>
SERVER_ID=gpu-server-1
```

Find the central dockprom IP on the central machine:

```bash
hostname -I | awk '{print $1}'
```

### 2. Start On Linux

Recommended:

```bash
chmod +x start.sh
./start.sh
```

The script:

- starts Linux exporters on Linux
- starts GPU collector only when `/dev/nvidia0` and `libnvidia-ml.so.*` exist
- skips GPU safely on CPU-only machines

Manual Linux CPU:

```bash
docker compose --profile linux up -d
```

Manual Linux GPU:

```bash
NVIDIA_ML_LIB_PATH=$(ls /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.* | sort -V | tail -n 1) \
docker compose --profile linux --profile gpu up -d
```

### 3. Start On Windows / CPU Test Machine

PowerShell:

```powershell
.\start.ps1
```

Or plain Compose:

```powershell
docker compose up -d
```

This intentionally starts only the CPU-safe collector.

## Central Prometheus Setup

The `otel-host-collector` and `otel-gpu-collector` push OTLP metrics to central
`dockprom` on port `4318`, so make sure that port is reachable:

```text
http://MAIN_SERVER_IP:4318
```

For Linux node/cAdvisor dashboards, also add the remote server IP to central
`dockprom/prometheus/prometheus.yml` under the `nodeexporter` and `cadvisor`
jobs:

```yaml
- targets: ['REMOTE_SERVER_IP:9100']
  labels:
    server_id: 'gpu-server-1'
```

```yaml
- targets: ['REMOTE_SERVER_IP:8080']
  labels:
    server_id: 'gpu-server-1'
```

Reload Prometheus:

```bash
curl -X POST http://admin:admin@localhost:9090/-/reload
```

## Verify

On the remote machine:

```bash
docker compose ps
docker logs --tail 30 otel-host-collector
docker logs --tail 30 otel-gpu-collector   # GPU profile only
```

On the central dockprom machine:

```bash
curl -s http://admin:admin@localhost:9090/api/v1/targets
```

Then open Grafana:

```text
http://MAIN_SERVER_IP:3000
```

Select the machine by `SERVER_ID` / `server_id` in dashboards.

## What Each Service Collects

| Service | Default? | Platform | Metrics |
|---|---:|---|---|
| `otel-host-collector` | yes | Windows Docker Desktop / Linux | CPU-safe host metrics pushed to central OTLP |
| `nodeexporter` | no, `linux` profile | Linux / Docker Desktop VM | CPU, RAM, disk, network, uptime for node dashboards on port `9100` |
| `cadvisor` | no, `linux` profile | Linux / Docker Desktop VM | Docker container metrics on port `8080` |
| `otel-gpu-collector` | no, `gpu` profile | Linux NVIDIA | GPU utilization, VRAM, temperature, power, clocks |
