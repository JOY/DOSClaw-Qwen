# Alibaba Cloud Deployment Runbook

This runbook describes the deployment path for the public Huyen hackathon bundle.

Use a separate Alibaba Cloud demo service. Do not redeploy, migrate, or recreate production DOSClaw agent containers for the hackathon.

## Recommended Shape

1. Export the sanitized bundle from the private monorepo.
2. Build a Docker image from the exported bundle.
3. Push the image to Alibaba Cloud Container Registry.
4. Run the image on Elastic Container Instance, Function Compute custom container, ACK, or ECS.
5. Verify `/`, `/api/demo`, and `/api/health`.

Why container first:

- Alibaba Cloud Elastic Container Instance runs packaged Docker images without managing ECS instances.
- Alibaba Cloud Container Registry is the natural proof point for image build/push.
- Function Compute custom containers require images in Alibaba Cloud Container Registry in the same region.

## Export

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/export-huyen-public.ps1
```

Output:

```text
.tmp/huyen-public
```

## Local Build

```bash
cd .tmp/huyen-public
docker build -t huyen-qwen-cloud:local .
docker run --rm -p 3010:3010 huyen-qwen-cloud:local
curl http://localhost:3010/api/health
curl http://localhost:3010/api/demo
```

Optional source build smoke before containerizing:

```bash
npm ci
npm run build
```

## Alibaba Cloud Container Registry

The deploy credential must have permission to read or create the target registry resources. Minimum practical actions for the container-first path:

```text
cr:ListInstance
cr:CreateNamespace
cr:CreateRepository
cr:GetAuthorizationToken
cr:ListRepository
cr:GetRepository
cr:ListRepoTag
```

Replace placeholders before running:

```bash
export ACR_REGISTRY=<registry-domain>
export ACR_NAMESPACE=<namespace>
export ACR_REPOSITORY=huyen-qwen-cloud
export IMAGE_TAG=hackathon-2026-06-08

docker login "$ACR_REGISTRY"
bash scripts/deploy-acr.sh
```

Record the pushed image URL in `deployment-proof.md`.

## Runtime Environment

Set these variables on the Alibaba Cloud runtime:

```bash
QWEN_CLOUD_API_KEY=<secret>
QWEN_CLOUD_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1
QWEN_CLOUD_MODEL=qwen3.7-plus
PORT=3010
```

The public demo app uses synthetic data. The real DOSClaw/OpenClaw agent uses the same Qwen Cloud env contract when `qwen_cloud_submission=true`.

## Post-Deploy Verification

```bash
export HUYEN_URL=https://<public-demo-domain>
```

Automated proof:

```powershell
$env:HUYEN_URL = "https://<public-demo-domain>"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke-scenarios.ps1
```

Manual equivalent:

```bash
curl "$HUYEN_URL/api/health"
curl "$HUYEN_URL/api/demo"
curl -X POST "$HUYEN_URL/api/demo" \
  -H "Content-Type: application/json" \
  -d '{"scenario":"memory"}'
curl -X POST "$HUYEN_URL/api/demo" \
  -H "Content-Type: application/json" \
  -d '{"scenario":"knowledge"}'
curl -X POST "$HUYEN_URL/api/demo" \
  -H "Content-Type: application/json" \
  -d '{"scenario":"handoff"}'
```

Capture:

- Public URL
- Image URL in Alibaba Cloud Container Registry
- Screenshot or CLI output showing Alibaba Cloud runtime
- Smoke output for all three scenarios

## Permission Preflight

Run these checks before attempting the deploy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preflight-alibaba.ps1
```

The equivalent manual checks are:

```bash
aliyun sts GetCallerIdentity
aliyun cr ListInstance
aliyun fc-open ListServices
aliyun eci ListUsage
```

If `cr:ListInstance` is denied, the image cannot be pushed to Alibaba Cloud Container Registry yet. If `fc:ListServices` or ECI usage is denied, the runtime cannot be created by that credential yet.

Use `docs/alibaba-ram-policy-huyen-deploy.json` as the scoped RAM policy template for the hackathon deploy credential. The policy intentionally covers only Container Registry plus the two supported runtime paths, Function Compute and Elastic Container Instance.

## Official Documentation References

- Alibaba Cloud Elastic Container Instance: `https://www.alibabacloud.com/help/en/eci/user-guide/overview`
- Alibaba Cloud Container Registry: `https://www.alibabacloud.com/help/en/container-registry`
- Alibaba Cloud Function Compute custom containers: `https://www.alibabacloud.com/help/en/functioncompute/fc-2-0/user-guide/create-a-custom-container-function`
