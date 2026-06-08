# Huyen Judging Packet

This packet maps Huyen directly to the Qwen Cloud hackathon submission requirements and judging criteria.

## Submission Fields

| Field | Huyen answer |
| --- | --- |
| Project name | Huyen |
| Track | Track 4: Autopilot Agent |
| Secondary fit | Track 1: MemoryAgent |
| Public repository | `https://github.com/JOY/huyen-qwen-cloud` |
| Demo URL | Pending Alibaba Cloud runtime permission unlock |
| Demo video URL | Pending recording after Alibaba Cloud deploy |
| Alibaba Cloud proof | Pending RAM permission unlock; see issue `https://github.com/JOY/huyen-qwen-cloud/issues/1` |
| Architecture diagram | `docs/architecture.mmd` |
| Open source license | `LICENSE` |

## Requirement Coverage

| Requirement | Status | Evidence |
| --- | --- | --- |
| Public open source code repository | Ready | `https://github.com/JOY/huyen-qwen-cloud` |
| Source code, assets, and functional instructions | Ready | `README.md`, `Dockerfile`, `.github/workflows/ci.yml`, `scripts/verify-public.ps1` |
| Open source license visible in repository | Ready | `LICENSE` |
| Qwen Cloud usage | Ready | `src/lib/qwen.ts`, `src/app/api/demo/route.ts`, `docs/huyen-agent-config.md` |
| Alibaba Cloud backend proof | Blocked | Current RAM user is denied ACR, Function Compute, and ECI actions; deploy code exists in `scripts/deploy-fc.ps1` and `scripts/deploy-eci.ps1` |
| Architecture diagram | Ready | `docs/architecture.mmd` |
| About 3-minute demo video | Recording packet ready | `docs/demo-script.md`, `docs/video-recording-packet.md` |
| Text description | Ready | `docs/devpost-draft.md` |
| Track identification | Ready | Track 4 primary in `docs/devpost-draft.md` |
| Smoke proof for live demo | Automated | `scripts/smoke-scenarios.ps1` writes `docs/proof/smoke-latest.json` |
| Optional blog or social post | Draft ready | `docs/blog-post-draft.md`, `docs/social-post-draft.md` |

## Judging Criteria Response

### Technical Depth and Engineering

Huyen uses Qwen Cloud through an OpenAI-compatible live adapter and keeps a synthetic fallback so the public repository is buildable without secrets. The DOSClaw/OpenClaw integration path supports opt-in Qwen Cloud provider injection, primary model selection, and MCP tool evidence for memory, knowledge, and handoff flows.

Evidence:

- `src/lib/qwen.ts`
- `src/app/api/demo/route.ts`
- `docs/huyen-agent-config.md`
- `scripts/smoke-scenarios.ps1`

### Innovation and AI Creativity

The project is positioned as a production SME support autopilot rather than a generic chatbot. It combines persistent memory, live knowledge lookup, and honest escalation into one focused business workflow.

Evidence:

- `docs/demo-script.md`
- `docs/video-recording-packet.md`
- `docs/architecture.mmd`
- `README.md`

### Problem Value and Impact

Vietnamese SMEs often run customer support through chat channels with informal staff handoff. Huyen addresses three concrete failure modes: forgetting repeat customers, guessing policy facts, and falsely claiming staff escalation.

Evidence:

- `docs/devpost-draft.md`
- `src/app/page.tsx`
- `scripts/smoke-scenarios.ps1`

### Presentation and Documentation

The public repo includes a clean README, architecture diagram, Devpost draft, demo script, deployment runbook, proof checklist, RAM policy template, and evidence package generator.

Evidence:

- `README.md`
- `docs/deployment-proof.md`
- `docs/alibaba-cloud-deploy.md`
- `scripts/deploy-fc.ps1`
- `scripts/deploy-eci.ps1`
- `docs/blog-post-draft.md`
- `docs/social-post-draft.md`
- `scripts/package-submission.ps1`

## Current Blocking Item

Alibaba Cloud deployment is blocked by RAM permissions for user `joy` in `ap-southeast-1`.

Required unlock:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preflight-alibaba.ps1
```

The preflight must pass before image push or runtime creation. Use `docs/alibaba-ram-policy-huyen-deploy.json` as the policy template.

## Final Submission Checklist

- [x] Public repo exists.
- [x] License exists.
- [x] Qwen Cloud live adapter exists.
- [x] Architecture diagram exists.
- [x] Demo script exists.
- [x] Smoke proof automation exists.
- [x] Evidence package automation exists.
- [x] Blog/social drafts exist.
- [ ] Alibaba Cloud runtime URL is live.
- [ ] Alibaba Cloud proof recording/link is captured.
- [ ] Demo video is recorded and public.
- [ ] Devpost form is submitted.
