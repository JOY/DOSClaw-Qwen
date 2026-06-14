# Alibaba Cloud Deployment

This app is designed for a small ECS deployment for the hackathon demo.

## Prerequisites

- Alibaba Cloud ECS with Docker and Docker Compose.
- A Qwen Cloud / DashScope API key.
- Port `80` reachable from the judge testing URL. The ECI source-bootstrap path runs an nginx sidecar that proxies public HTTP to the app on internal port `8092`.

## RAM Permissions

Run the read-only preflight before deployment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preflight-alibaba.ps1
```

For the managed-container scripts, the deploy user needs, at minimum:

- ACR read/write access for image push and repository lookup.
- Either Function Compute permissions for `scripts/deploy-fc.ps1`, or Elastic Container Instance permissions for `scripts/deploy-eci.ps1`.
- Network permissions for the chosen runtime path, such as VSwitch/Security Group references for ECI.
- ECI public deployments can use the default TCP `80` security-group rule through the nginx sidecar. If your account does not create that rule automatically, grant `ecs:AuthorizeSecurityGroup` so the deploy script can open the public port.
- EIP describe/release permissions are useful for cleaning up auto-created test EIPs during deployment troubleshooting.

Use `infra/alibaba/ram-policy-dosclaw-qwen-deploy.json` as the deploy policy template. It covers
the managed-container path plus ECS/VPC read-only checks used by preflight.

The current managed-container scripts intentionally fail before mutation when these permissions are missing.

For the fastest no-registry hackathon path, deploy a source-bootstrapped ECI group. It runs a
Postgres/pgvector sidecar, a Python app container that clones this public repo, and an nginx
sidecar that exposes the app on public HTTP port `80`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-eci-source.ps1 -ReplaceExisting
```

If you already have an ECS host with SSH access, you can deploy without ACR/FC/ECI RAM permissions:

```powershell
$env:DASHSCOPE_API_KEY = "<secret>"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-ecs-ssh.ps1 -HostName "<ecs-public-ip-or-host>"
```

That path clones the public repo on the ECS host, writes a server-side `.env`, starts Postgres, builds the app image locally on the ECS host, seeds embeddings, and verifies `/api/health`.

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
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-scenarios.ps1 -BaseUrl "http://<ecs-or-eci-host>"
```

For a no-key container health check, add `-SkipLiveChat`.
