# DOSClaw-Qwen Submission Status

Last refreshed: 2026-06-15.

## Ready For Devpost

- Public repository: https://github.com/JOY/DOSClaw-Qwen
- Track: MemoryAgent.
- License: MIT.
- Live demo URL: http://8.219.211.170/
- Demo login: none required for the current public demo.
- Qwen Cloud proof code: `dosclaw_qwen/model.py`.
- FastAPI demo surface: `dosclaw_qwen/app.py`.
- Alibaba runtime proof notes: `docs/deployment-proof.md`.
- Architecture diagram: `docs/architecture.mmd`.
- Architecture PNG for Devpost upload: `docs/architecture.png`.
- Architecture SVG for Devpost: `docs/architecture.svg`.
- Paste-ready Devpost fields: `docs/devpost-submission-fields.md`.
- Judging packet: `docs/judging-packet.md`.
- Demo script: `docs/demo-script.md`.
- Video recording packet: `docs/video-recording-packet.md`.
- Evidence package generator: `scripts/package-submission.ps1`.
- Optional local video renderer: `scripts/render-demo-video.ps1`.

## Verified Live Runtime

- Runtime type: Alibaba Cloud Elastic Container Instance in `ap-southeast-1`.
- Public entrypoint: nginx sidecar on HTTP port `80`.
- App runtime: Python FastAPI container.
- Durable stores: Postgres/pgvector sidecar plus Qdrant sidecar for Mem0Middleware.
- Chat model: `qwen3.6-plus`.
- Embedding model: `text-embedding-v4`.
- Agent runtime: AgentScope 2.0.
- Memory engine: Mem0Middleware plus the structured profile layer.
- Memory scope: `tenant_id + customer_id`.
- Memory controls: Mem0 list, get, search, add, update, delete, delete-all, and history endpoints.
- Agent memory mode: automatic recall/write-back plus `search_memory` and `add_memory` tools.

Fresh runtime details are available at:

```text
http://8.219.211.170/api/runtime
```

## Verified Demo Behaviors

- Returning Customer A recalls lactose intolerance and oat-milk preference.
- New Customer B does not inherit Customer A memory.
- Customer B can teach a profile fact such as name and age.
- A later Customer B session recalls the profile.
- Knowledge questions can invoke tenant FAQ search.
- The Knowledge base panel exposes tenant FAQ rows and search results.
- The Memory controls panel exposes scoped Mem0 management actions.
- Refund or complaint escalation can invoke `human_handoff` and return a ticket.
- Assistant reply metadata exposes Qwen model, embeddings, AgentScope/Mem0/Qdrant, memory scope, and streamed tool calls.
- Pressing Enter submits the chat message.
- The composer unlocks after the final assistant reply.

## Evidence Commands

Run these before packaging or final submission:

```powershell
.\.venv\Scripts\python.exe -m pytest
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\smoke-scenarios.ps1 -BaseUrl http://8.219.211.170 -OutputPath docs\proof\eci-smoke-latest.json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package-submission.ps1
```

The generated evidence package is:

```text
docs/proof/dosclaw-qwen-submission-evidence.zip
```

## External Submission Items

These cannot be completed inside the repository alone:

- Record and upload a public or unlisted demo video under 3 minutes to YouTube, Vimeo, or Youku.
- Paste the final video URL into Devpost and, optionally, into `docs/devpost-submission-fields.md` and `docs/judging-packet.md`.
- Submit the Devpost form with the live demo URL, repository URL, Qwen Cloud proof code link, architecture notes, and MemoryAgent track selection.

The repository includes `scripts/render-demo-video.ps1` to turn captured UI screenshots into a local MP4, but the final Devpost requirement is still a public or unlisted video URL from an external video host.
