# DOSClaw-Qwen Judging Packet

## Project

DOSClaw-Qwen is an AgentScope 2.0 + Qwen Cloud customer-support agent for the MemoryAgent track. It is designed for SMEs that need a support assistant that remembers customer preferences without mixing customers together.

## What To Test

Use the web demo and run the four-step flow in `docs/demo-script.md`:

1. Select `Returning Customer A`.
2. Ask: `I'm lactose intolerant. What do you recommend?`
3. Switch to `New Customer B` and ask: `Do you remember my usual drink?`
4. Ask a return-policy question, then a refund escalation question.

Expected result: Customer A's profile appears in the memory panel and informs the answer; Customer B does not inherit Customer A's profile; knowledge search grounds business-policy answers; refund complaints create a handoff ticket. Assistant reply metadata shows the active Qwen model, Mem0/Qdrant backend, and tool calls.

The sidebar also exposes direct demo evidence: Mem0 memory list/get/search/add/update/delete/delete-all/history controls and a tenant knowledge-base panel.

## Why This Is Not A Scripted Chatbot

- Customer memory is persisted and scoped by `user_id=customer_id` and `agent_id=tenant_id`.
- AgentScope streams real agent events through `/api/chat`.
- Qwen Cloud is used for chat, structured profile extraction, FAQ embeddings, and mem0 memory extraction.
- Mem0 runs in `both` mode: automatic recall/write-back plus `search_memory` and `add_memory` tools available to the agent.
- Handoffs are stored in Postgres and can be verified in the `handoffs` table.
- Tool activity is streamed as `tool_info` events and displayed under the assistant reply.

## Required Links

- Repository: https://github.com/JOY/DOSClaw-Qwen
- Qwen Cloud usage: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py
- Demo API: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/app.py
- Deployment scripts: https://github.com/JOY/DOSClaw-Qwen/tree/main/scripts
- Architecture: https://github.com/JOY/DOSClaw-Qwen/blob/main/ARCHITECTURE.md
- Architecture diagram PNG: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.png
- Architecture diagram SVG: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg
- Devpost paste sheet: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/devpost-submission-fields.md

## Current Deployment

The public demo is live on Alibaba Cloud Elastic Container Instance:

- Live demo URL: `http://8.219.211.170/`
- Runtime: Python app container, Postgres/pgvector sidecar, Qdrant sidecar, and nginx public proxy sidecar.
- Smoke evidence: `docs/proof/eci-smoke-latest.json`

The repo also includes:

- `scripts/preflight-alibaba.ps1` for ACR/FC/ECI or ECS read-only checks.
- `scripts/deploy-fc.ps1` for Function Compute.
- `scripts/deploy-eci.ps1` for Elastic Container Instance.
- `scripts/deploy-eci-source.ps1` for the source-bootstrapped ECI path used for the live demo.
- `scripts/deploy-ecs-ssh.ps1` for an existing ECS host.

## Final Submission Placeholders

- Live demo URL: `http://8.219.211.170/`
- Demo login: none required for the current public demo.
- Video URL: add the public or unlisted YouTube, Vimeo, or Youku URL after upload.
- Alibaba proof: use the live URL, `docs/deployment-proof.md`, `scripts/deploy-eci-source.ps1`, and `dosclaw_qwen/model.py`. If the Devpost form asks for a separate runtime proof clip, record `/api/runtime`, the live app, the ECI console, and the code proof link.
