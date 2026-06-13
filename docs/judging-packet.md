# DOSClaw-Qwen Judging Packet

## Project

DOSClaw-Qwen is an AgentScope 2.0 + Qwen Cloud customer-support agent for the MemoryAgent track. It is designed for SMEs that need a support assistant that remembers customer preferences without mixing customers together.

## What To Test

Use the web demo and run the four-step flow in `docs/demo-script.md`:

1. Select `Returning Customer A`.
2. Ask: `I'm lactose intolerant. What do you recommend?`
3. Switch to `New Customer B` and ask: `Do you remember my usual drink?`
4. Ask a return-policy question, then a refund escalation question.

Expected result: Customer A's profile appears in the memory panel and informs the answer; Customer B does not inherit Customer A's profile; knowledge search grounds business-policy answers; refund complaints create a handoff ticket.

## Why This Is Not A Scripted Chatbot

- Customer memory is persisted and scoped by `user_id=customer_id` and `agent_id=tenant_id`.
- AgentScope streams real agent events through `/api/chat`.
- Qwen Cloud is used for chat, structured profile extraction, FAQ embeddings, and mem0 memory extraction.
- Handoffs are stored in Postgres and can be verified in the `handoffs` table.

## Required Links

- Repository: https://github.com/JOY/DOSClaw-Qwen
- Qwen Cloud usage: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py
- Demo API: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/app.py
- Deployment scripts: https://github.com/JOY/DOSClaw-Qwen/tree/main/scripts
- Architecture: https://github.com/JOY/DOSClaw-Qwen/blob/main/ARCHITECTURE.md

## Current Deployment Gate

The code is ready for Alibaba deployment, but the current RAM user must be granted deployment permissions or a known ECS host with SSH access. The repo includes:

- `scripts/preflight-alibaba.ps1` for ACR/FC/ECI or ECS read-only checks.
- `scripts/deploy-fc.ps1` for Function Compute.
- `scripts/deploy-eci.ps1` for Elastic Container Instance.
- `scripts/deploy-ecs-ssh.ps1` for an existing ECS host.

## Final Submission Placeholders

- Live demo URL: TODO
- Demo login: TODO
- Video URL: TODO
- Public Alibaba proof recording: TODO
