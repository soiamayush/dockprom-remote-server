# dockprom-remote-server

Lightweight monitoring agent for GPU machines. Sends host, container, and GPU metrics to a central [dockprom](https://github.com/soiamayush/dockprom) dashboard.

## How it works

```
  Machine 1 (central)                    Machine 2 (remote)
  ─────────────────────                  ──────────────────────────
  github.com/soiamayush/dockprom         github.com/soiamayush/dockprom-remote-server
  Prometheus + Grafana + AlertManager    node-exporter
  otel-collector (port 4318 open)   ←── cAdvisor
  All dashboards here                    otel-gpu-collector (pushes GPU metrics)
```

Both machines show up in every Grafana dashboard — switch between them using the `server` dropdown.

---

## Setup

### Machine 1 — Central monitoring stack

```bash
git clone https://github.com/soiamayush/dockprom.git
cd dockprom

ADMIN_USER='admin' ADMIN_PASSWORD='admin' \
ADMIN_PASSWORD_HASH='$2a$14$1l.IozJx7xQRVmlkEQ32OeEEfP5mRxTpbDTCTcXRqn19gXD8YK1pO' \
docker compose up -d
```

Grafana → `http://MACHINE1_IP:3000` (admin / admin)

Note your IP — you'll need it for machine 2:
```bash
hostname -I | awk '{print $1}'
```

---

### Machine 2 — Remote GPU agent

**1. Clone**
```bash
git clone https://github.com/soiamayush/dockprom-remote-server.git
cd dockprom-remote-server
```

**2. Configure**
```bash
cp .env.example .env
```
Open `.env` and set:
```
MAIN_SERVER_IP=<IP of machine 1>
SERVER_ID=gpu-server-2
```

**3. Find your NVIDIA lib version**
```bash
ls /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.*
```
Open `docker-compose.yml`, replace `REPLACE_VERSION` with the version number you see (e.g. `550.90.07`):
```yaml
# before
- /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.REPLACE_VERSION:...
# after
- /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.550.90.07:...
```

**4. Start**
```bash
docker compose up -d
```

**5. Add machine 2 to Prometheus (on machine 1)**

On machine 1, open `dockprom/prometheus/prometheus.yml`.
Find the `# Add remote servers here` comments and uncomment + fill in machine 2's IP (2 places — nodeexporter and cadvisor):
```yaml
- targets: ['MACHINE2_IP:9100']
  labels:
    server_id: 'gpu-server-2'
```

Then reload Prometheus — no restart needed:
```bash
curl -X POST http://admin:admin@localhost:9090/-/reload
```

---

## Verify

```bash
# on machine 2
docker compose ps                  # all 3 should be "running"
docker logs otel-gpu-collector     # no errors

# on machine 1
# open http://MACHINE1_IP:9090/targets — machine 2 nodeexporter + cadvisor should be UP
# open http://MACHINE1_IP:3000 → GPU Monitoring dashboard → server dropdown → both machines visible
```

---

## What each container collects

| Container | Metrics |
|-----------|---------|
| node-exporter | CPU, RAM, disk, network, uptime |
| cAdvisor | Docker container metrics |
| otel-gpu-collector | GPU utilization, VRAM, temperature, power, clock speed |
