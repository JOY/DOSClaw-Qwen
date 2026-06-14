# Deployment Proof Notes

## What Counts For The Submission

The hackathon asks for proof of Alibaba Cloud deployment and a link to code that uses Alibaba Cloud services or APIs.

DOSClaw-Qwen has two proof layers:

1. Qwen Cloud API usage in source code: `dosclaw_qwen/model.py` constructs DashScope chat and embedding clients.
2. Runtime deployment on Alibaba Cloud: ECS, Function Compute, or Elastic Container Instance running the Dockerized FastAPI app and Postgres/pgvector.

## Current Runtime Status

The public Alibaba Cloud runtime is live on Elastic Container Instance in `ap-southeast-1`.
It runs a Python app container, a Postgres/pgvector sidecar, a Qdrant sidecar for mem0 episodic
memory, and an nginx sidecar that exposes the app on public HTTP port `80`.

Runtime metadata is exposed at `/api/runtime` and includes the current git SHA, Qwen chat model,
Qwen embedding model, AgentScope runtime, Mem0Middleware, vector store backend, and memory scope.

Use the current preflight script to record Alibaba Cloud API access:

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

## Final Fields

- Alibaba public URL: `http://8.219.211.170/`
- Runtime type: Elastic Container Instance source bootstrap with Python app, Postgres/pgvector sidecar, Qdrant sidecar, and nginx public proxy.
- Demo login: none required for the current public demo.
- Smoke evidence path: `docs/proof/eci-smoke-latest.json`
- Video URL: add after recording and upload.
