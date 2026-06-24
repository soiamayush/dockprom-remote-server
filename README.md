# dockprom-remote-server

Lightweight agent for GPU machines. Sends host, container, and GPU metrics to a central [dockprom](https://github.com/soiamayush/dockprom) dashboard.

## What runs on your machine

| Container | Metrics |
|-----------|---------|
| node-exporter | CPU, RAM, disk, network |
| cAdvisor | Docker container metrics |
| otel-gpu-collector | GPU utilization, VRAM, temp, power |

## Setup

**1. Clone**
```bash
git clone https://github.com/soiamayush/dockprom-remote-server.git
cd dockprom-remote-server
```

**2. Configure**
```bash
cp .env.example .env
```
Edit `.env` — set your two values:
- `MAIN_SERVER_IP` — IP of the central monitoring server
- `SERVER_ID` — any unique name for your machine

**3. Find your NVIDIA lib version**
```bash
ls /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.*
```
In `docker-compose.yml`, replace `REPLACE_VERSION` with your actual version number.

**4. Start**
```bash
docker compose up -d
```

**5. Send your IP to Ayush**
```bash
hostname -I | awk '{print $1}'
```
He'll add it to Prometheus and your machine shows up on all dashboards.

## Verify

```bash
docker compose ps          # all 3 containers should be running
docker logs otel-gpu-collector   # check for any errors
```
