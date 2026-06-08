# Deployment Proof Plan

This file tracks the proof needed for the Qwen Cloud hackathon submission. Fill the unchecked items only after the Alibaba Cloud deployment is live.

## Required Proof

- [x] Standalone public bundle builds outside the private monorepo.
- [x] Standalone public bundle builds as a Docker image.
- [x] Local Docker container serves `/api/health` and `/api/demo`.
- [ ] Public app URL for the Huyen demo surface.
- [ ] Alibaba Cloud service URL or console screenshot proving the backend is hosted on Alibaba Cloud.
- [x] Public code link showing Qwen Cloud environment variables and provider wiring.
- [x] Public code link showing the demo API or runtime adapter.
- [ ] Smoke-test output for one memory scenario.
- [ ] Smoke-test output for one knowledge scenario.
- [ ] Smoke-test output for one handoff scenario.

## Public Source

- Repository: `https://github.com/JOY/huyen-qwen-cloud`
- Qwen Cloud env contract: `https://github.com/JOY/huyen-qwen-cloud/blob/main/docs/huyen-agent-config.md`
- Live Qwen Cloud adapter: `https://github.com/JOY/huyen-qwen-cloud/blob/main/src/lib/qwen.ts`
- Runtime deployment guide: `https://github.com/JOY/huyen-qwen-cloud/blob/main/docs/alibaba-cloud-deploy.md`
- Function Compute deploy script: `https://github.com/JOY/huyen-qwen-cloud/blob/main/scripts/deploy-fc.ps1`
- Elastic Container Instance deploy script: `https://github.com/JOY/huyen-qwen-cloud/blob/main/scripts/deploy-eci.ps1`
- Demo API: `https://github.com/JOY/huyen-qwen-cloud/blob/main/src/app/api/demo/route.ts`
- Health API: `https://github.com/JOY/huyen-qwen-cloud/blob/main/src/app/api/health/route.ts`

## Alibaba Cloud Permission Gate

Last checked on 2026-06-08:

- `aliyun sts GetCallerIdentity` succeeds.
- `aliyun cr ListInstance` is denied for the current RAM user, so the image cannot be pushed to Alibaba Cloud Container Registry yet.
- `aliyun fc-open ListServices` is denied for the current RAM user, so Function Compute cannot be created by this credential yet.
- `aliyun eci ListUsage` is denied for the current RAM user, so Elastic Container Instance cannot be created by this credential yet.

Grant the deploy credential the ACR and runtime permissions listed in `docs/alibaba-cloud-deploy.md`, then rerun the post-deploy smoke commands.

Permission unlock packet:

- Preflight script: `https://github.com/JOY/huyen-qwen-cloud/blob/main/scripts/preflight-alibaba.ps1`
- RAM policy template: `https://github.com/JOY/huyen-qwen-cloud/blob/main/docs/alibaba-ram-policy-huyen-deploy.json`

## Candidate Deployment Shape

Use a separate Alibaba Cloud service for the hackathon demo. Do not move or recreate production DOSClaw fleet containers for the submission.

Recommended minimum:

1. Deploy `apps/huyen` as the public product surface.
2. Deploy a sanitized demo backend or adapter that exposes `/api/demo`.
3. Configure Qwen Cloud env vars on the Alibaba Cloud runtime:

```bash
QWEN_CLOUD_API_KEY=<secret>
QWEN_CLOUD_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1
QWEN_CLOUD_MODEL=qwen3.7-plus
```

## Smoke Commands

Use the proof script after local run or deployed Alibaba Cloud run:

```powershell
$env:HUYEN_URL = "https://<huyen-demo-domain>"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-scenarios.ps1
```

It checks `/api/health`, all three `/api/demo` scenarios, the `qwen-cloud/*` model ref, MCP tool evidence, and `answerSource`. It writes JSON evidence to `docs/proof/smoke-latest.json`.

Package all submission evidence after a smoke run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/package-submission.ps1
```

The package includes Devpost copy, architecture, deployment checklist, preflight/smoke scripts, RAM policy, public links, and JSON proof files under `docs/proof/`.

## Current Private-Repo Evidence

- `apps/huyen` is the standalone product slice.
- `services/api-gateway/service/agent/templates.go` injects the `qwen-cloud` provider into OpenClaw config when the agent opts in.
- `services/api-gateway/service/agent/agent_service.go` injects Qwen Cloud env vars only for opt-in agents.
- `docs/hackathons/qwen-cloud-2026/huyen-agent-config.md` defines the safe demo payload.
- `scripts/export-huyen-public.ps1` exports a sanitized public bundle to `.tmp/huyen-public`.

## Local Smoke Evidence

Last verified on 2026-06-08:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/export-huyen-public.ps1
Copy-Item .tmp/huyen-public $env:TEMP/huyen-public-verify -Recurse
cd $env:TEMP/huyen-public-verify
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-public.ps1
```

Result:

```text
Route (app)
┌ ○ /
├ ○ /_not-found
├ ƒ /api/demo
└ ƒ /api/health
```

The verification script performs a clean install, production Next build, Docker image build, local container run, `/api/health` check, and all three `/api/demo` scenario checks.
It also runs `scripts/smoke-scenarios.ps1` against the local Docker container and writes `docs/proof/local-smoke-latest.json`.

```json
{
  "health": {
    "ok": true,
    "service": "huyen",
    "modelProvider": "qwen-cloud",
    "runtime": "nextjs"
  },
  "handoff": {
    "ok": true,
    "scenario": "handoff",
    "evidence": {
      "qwenPrimaryModelRef": "qwen-cloud/qwen3.7-plus",
      "mcpTools": ["handoff_to_human"]
    }
  }
}
```

The first smoke caught and fixed a real export bug: `package.json` was written with a UTF-8 BOM, which Turbopack rejected. The export script now writes `package.json` and the generated root `README.md` as UTF-8 without BOM.
