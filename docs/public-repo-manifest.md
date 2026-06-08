# Public Repository Manifest

The public hackathon repository should be a sanitized slice, not a dump of the private DOS-AI monorepo.

## Include

- `apps/huyen`
- `scripts/export-huyen-public.ps1` output as repository root
- `.github/workflows/ci.yml`
- `scripts/verify-public.ps1`
- `scripts/smoke-scenarios.ps1`
- `scripts/package-submission.ps1`
- `scripts/deploy-fc.ps1`
- `scripts/deploy-eci.ps1`
- `scripts/deploy-acr.sh`
- `docs/hackathons/qwen-cloud-2026/devpost-draft.md`
- `docs/hackathons/qwen-cloud-2026/blog-post-draft.md`
- `docs/hackathons/qwen-cloud-2026/social-post-draft.md`
- `docs/hackathons/qwen-cloud-2026/judging-packet.md`
- `docs/hackathons/qwen-cloud-2026/demo-script.md`
- `docs/hackathons/qwen-cloud-2026/video-recording-packet.md`
- `docs/hackathons/qwen-cloud-2026/architecture.mmd`
- `docs/hackathons/qwen-cloud-2026/alibaba-cloud-deploy.md`
- `docs/hackathons/qwen-cloud-2026/alibaba-ram-policy-huyen-deploy.json`
- `docs/hackathons/qwen-cloud-2026/huyen-agent-config.md`
- A short `README.md` at the repository root
- An open source license

## Export Command

Run this from the private monorepo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/export-huyen-public.ps1
```

The sanitized bundle is written to:

```text
.tmp/huyen-public
```

Smoke test the bundle outside this monorepo before publishing:

```powershell
$dst = Join-Path $env:TEMP "huyen-public-smoke"
if (Test-Path $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
Copy-Item -LiteralPath ".tmp/huyen-public" -Destination $dst -Recurse
cd $dst
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-public.ps1
```

## Exclude

- Production API keys or encrypted token blobs
- Private customer data
- Internal deployment hostnames that are not part of the public demo
- Production DOSClaw runbooks
- Private Supabase schema dumps
- Full DOS-AI dashboard source
- Any `.env` file

## Root README Outline

```markdown
# Huyen

Huyen is a Qwen Cloud-powered Vietnamese SME support autopilot.

## Demo

<public URL>

## Architecture

OpenClaw orchestrates the agent runtime. DOSClaw supplies memory, knowledge, and handoff tools. Qwen Cloud powers the primary reasoning path.

## Run

npm ci
npm run dev

## Environment

QWEN_CLOUD_API_KEY=
QWEN_CLOUD_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1
QWEN_CLOUD_MODEL=qwen3.7-plus
```
