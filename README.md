# Huyen

Huyen is a Qwen Cloud-powered Vietnamese SME support autopilot for the Qwen Cloud hackathon.

## Demo

The app demonstrates three production customer-support workflows:

- returning customer memory
- live knowledge lookup
- honest human handoff

## Architecture

OpenClaw orchestrates the runtime container and chat channels. DOSClaw supplies memory, knowledge, and handoff tools. Qwen Cloud powers the primary reasoning path through the OpenAI-compatible DashScope endpoint.

## Run Locally

```bash
npm ci
npm run dev
```

Open `http://localhost:3010`.

## Build

```bash
npm run build
```

## Container

```bash
docker build -t huyen-qwen-cloud:local .
docker run --rm -p 3010:3010 huyen-qwen-cloud:local
curl http://localhost:3010/api/health
```

## Verify

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-public.ps1
```

## Push to Alibaba Cloud Container Registry

```bash
export ACR_REGISTRY=<registry-domain>
export ACR_NAMESPACE=<namespace>
export ACR_REPOSITORY=huyen-qwen-cloud
export IMAGE_TAG=hackathon-2026-06-08
bash scripts/deploy-acr.sh
```

## Environment

```bash
QWEN_CLOUD_API_KEY=
QWEN_CLOUD_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1
QWEN_CLOUD_MODEL=qwen3.7-plus
```

## Demo API

```bash
curl http://localhost:3010/api/demo
curl -X POST http://localhost:3010/api/demo -H "Content-Type: application/json" -d '{"scenario":"handoff"}'
curl http://localhost:3010/api/health
```

See `docs/` for Devpost copy, architecture, demo script, and deployment proof checklist.
