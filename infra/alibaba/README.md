# Alibaba Cloud Deployment

This app is designed for a small ECS deployment for the hackathon demo.

## Prerequisites

- Alibaba Cloud ECS with Docker and Docker Compose.
- A Qwen Cloud / DashScope API key.
- Port `8092` reachable from the judge testing URL, or a reverse proxy forwarding HTTPS to `8092`.

## RAM Permissions

Run the read-only preflight before deployment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preflight-alibaba.ps1
```

The deploy user needs, at minimum:

- ACR read/write access for image push and repository lookup.
- Either Function Compute permissions for `scripts/deploy-fc.ps1`, or Elastic Container Instance permissions for `scripts/deploy-eci.ps1`.
- Network permissions for the chosen runtime path, such as VSwitch/Security Group references for ECI.

The current scripts intentionally fail before mutation when these permissions are missing.

## Environment

Create a server-side `.env` file. Do not commit it.

```bash
DASHSCOPE_API_KEY=<secret>
DASHSCOPE_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1
QWEN_CHAT_MODEL=qwen3.6-plus
QWEN_EMBED_MODEL=text-embedding-v4
DATABASE_URL=postgresql://dosclaw_qwen:dosclaw_qwen@db:5432/dosclaw_qwen
DEFAULT_TENANT_ID=tenant_demo
DEMO_LOGIN_USER=judge
DEMO_LOGIN_PASS=<demo-password>
```

## Run

```bash
docker compose up -d db
docker build -t dosclaw-qwen:latest .
docker run -d --name dosclaw-qwen --env-file .env --network dosclaw-qwen_default -p 8092:8092 dosclaw-qwen:latest
docker exec -i dosclaw-qwen-db-1 psql -U dosclaw_qwen -d dosclaw_qwen < db/schema.sql
docker exec -i dosclaw-qwen-db-1 psql -U dosclaw_qwen -d dosclaw_qwen < db/seed.sql
docker exec dosclaw-qwen python -m dosclaw_qwen.seed_embeddings
```

## Smoke Test

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-scenarios.ps1 -BaseUrl "http://<ecs-host>:8092"
```

For a no-key container health check, add `-SkipLiveChat`.
