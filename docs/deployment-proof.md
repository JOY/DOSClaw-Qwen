# Deployment Proof Notes

## What Counts For The Submission

The hackathon asks for proof of Alibaba Cloud deployment and a link to code that uses Alibaba Cloud services or APIs.

DOSClaw-Qwen has two proof layers:

1. Qwen Cloud API usage in source code: `dosclaw_qwen/model.py` constructs DashScope chat and embedding clients.
2. Runtime deployment on Alibaba Cloud: ECS, Function Compute, or Elastic Container Instance running the Dockerized FastAPI app and Postgres/pgvector.

## Current Runtime Status

Local live Qwen Cloud verification has passed, but public Alibaba runtime creation is blocked by RAM permissions until the deploy user can either:

- use ACR plus Function Compute or Elastic Container Instance; or
- access an existing ECS host through SSH with inbound app traffic opened.

Use the current preflight script to record the exact gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preflight-alibaba.ps1 -Mode ManagedContainer -OutputPath docs/proof/alibaba-managed-preflight-latest.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preflight-alibaba.ps1 -Mode EcsReadOnly -OutputPath docs/proof/alibaba-ecs-preflight-latest.json
```

The evidence JSON intentionally stores only sanitized check names, commands, status, error codes, auth actions, and permission type. It does not store raw cloud diagnostics or secrets.

## Deployment Paths

Managed container path:

1. Run `scripts/preflight-alibaba.ps1 -Mode ManagedContainer`.
2. Push image with `scripts/deploy-acr.sh`.
3. Deploy with `scripts/deploy-fc.ps1` or `scripts/deploy-eci.ps1`.
4. Run `scripts/smoke-scenarios.ps1 -BaseUrl "<public-url>"`.

Known ECS host path:

```powershell
$env:DASHSCOPE_API_KEY = "<secret>"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-ecs-ssh.ps1 -HostName "<ecs-public-ip-or-host>"
```

That script clones the public repo on the ECS host, writes a server-side `.env`, starts Postgres, builds the app image on the host, seeds embeddings, and verifies `/api/health`.

## Final Fields To Fill

- Alibaba public URL: TODO
- Runtime type: TODO
- Demo login: TODO
- Smoke evidence path: TODO
- Video URL: TODO
