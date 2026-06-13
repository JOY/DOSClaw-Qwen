# DOSClaw-Qwen - Build Handoff (for Codex / the implementing agent)

You are picking up a hackathon project cold. This file is self-contained: read it fully, then
the four docs it points to, then start building. Code and docs in **English**. Deadline:
**2026-07-09 14:00 PT** (comfortable - build correctly, MVP first).

## What we are building

**DOSClaw-Qwen** - an SME customer-support agent with **per-customer persistent memory**. The agent
is **multilingual** (Qwen handles many languages), but the **demo runs in English** so global judges
can follow. NOTE: older reference docs (`spec-design.md`, `implementation-plan.md`) may still say
"Huyen" or "Vietnamese" - the project is now **DOSClaw-Qwen**, **English-first**; treat those as superseded.
Entry for the **Global AI Hackathon Series with Qwen Cloud** (Devpost), **MemoryAgent track**.
The differentiator (what judges score) is a real memory engine: a durable structured **profile**
+ decaying **episodic** memory in **pgvector**, recalled into a compact context block by
**semantic similarity + recency**, with active **forgetting/consolidation**. Two tools:
`knowledge_search` (shop FAQ RAG) and `human_handoff` (escalate). A web chat UI lets a judge pick a
customer and a "new session" to watch cross-session, per-customer recall happen.

**Stack:** Python 3.11 (Docker) / 3.14 (local OK), **AgentScope 2.0.1** (Alibaba's OSS agent
framework), **Qwen Cloud / DashScope** (`qwen3.6-plus` chat + `text-embedding-v4`), **Postgres +
pgvector**, asyncpg, FastAPI + uvicorn, all **deployed on Alibaba Cloud** (ECS + Dockerized
Postgres, or RDS). Qwen Cloud is the model/embedding API; this is what makes the entry an Alibaba
+ Qwen build.

## Read these, in order

0. **`docs/MEMORY_STACK.md`** - the MEMORY architecture decision (READ FIRST): DOSClaw-Qwen runs on
   **AgentScope 2.0** and gets long-term memory from the **`Mem0Middleware`** in upstream **PR #1775**
   (mem0 routed through our DashScope/Qwen model - no OpenAI; until merged, install from
   `git+https://github.com/Osier-Yi/agentscope.git@mem0-dev`). We add a custom layer (profile, recall
   composition, UI) and contribute a DOSClaw-Qwen **example** upstream (NOT a duplicate PR). This
   **supersedes the hand-rolled store/episodic design** in implementation-plan.md AND §5 of
   AGENTSCOPE_API.md. Read it before Phase 2.
1. **`docs/AGENTSCOPE_API.md`** - the VERIFIED AgentScope 2.0.1 API (introspected from the
   installed package). **Authoritative.** The implementation-plan below was written before this
   verification and uses several wrong symbols (`ReActAgent`, `agentscope.memory`,
   `register_tool_function`, `DashScopeChatModel(api_key=...)`). **Where they conflict, AGENTSCOPE_API.md wins.**
2. **`docs/implementation-plan.md`** - task-by-task plan (TDD, exact file paths, commits). The
   **memory engine design and task breakdown are correct**; only swap the AgentScope wiring for
   what AGENTSCOPE_API.md specifies.
3. **`docs/spec-design.md`** - the design rationale (the "why": memory model, demo flow, scope).
4. **`docs/hackathon-reference.md`** - rules, deliverables, judging weights, prizes, resource links.

## Current repo state (already done)

- **Scaffold present at repo root** (Task 0 of the plan is DONE): `requirements.txt` (deps verified
  to install on 3.14), `docker-compose.yml` (pgvector Postgres), `.env.example`, `.gitignore`,
  `db/schema.sql` (customers, customer_profile, episodic_memory[vector(1024)], knowledge, handoffs),
  `db/seed.sql` (2 demo customers; episodic+knowledge rows need embeddings - a seed script does that),
  `dosclaw_qwen/__init__.py`, and empty `web/ tests/ infra/alibaba/`.
- **`docs/legacy/`** - assets from a PRIOR, abandoned Next.js/TypeScript attempt (a scripted demo,
  not a real memory engine). It was **never deployed live to Alibaba**. **Mine it for reusable
  material but treat its architecture as outdated:**
  - `docs/legacy/devpost-draft.md`, `judging-packet.md`, `demo-script.md`,
    `video-recording-packet.md`, `blog-post-draft.md`, `social-post-draft.md` - submission
    narrative you can adapt (re-point from "OpenClaw/DOSClaw/Next.js" to "AgentScope + real memory").
  - `docs/legacy/alibaba-cloud-deploy.md`, `alibaba-ram-policy-dosclaw_qwen-deploy.json` - Alibaba deploy notes/RAM policy.
- **`scripts/`** - Alibaba deploy scripts from the old attempt (`deploy-fc.ps1`, `deploy-eci.ps1`,
  `deploy-acr.sh`, `preflight-alibaba.ps1`, `package-submission.ps1`, `smoke-scenarios.ps1`,
  `verify-public.ps1`). They build/push/deploy a **container** - reusable for the Python container
  with adaptation (the old Dockerfile was Next.js; you will write a Python one per the plan).
- **`LICENSE`** = MIT (valid OSS license for the hackathon - keep it).
- The old Next.js code is preserved on branch **`legacy-nextjs-demo`** (pushed). `main` is the new Python build.

## Build order (from the plan, with AGENTSCOPE_API.md corrections)

Work in this repo on `main` (or a feature branch off it). Follow TDD where the plan marks it.
1. **Confirm-by-introspection checklist** (AGENTSCOPE_API.md section 6) - lock the last few signatures.
2. **Phase 1 - `dosclaw_qwen/ranking.py` + `tests/test_ranking.py`** (TDD, pure logic: `decay_score`,
   `rank_episodes`, `merge_profile`). No DB/LLM. `pytest` must pass. This is the only fully
   offline-testable unit and the core of the memory scoring - do it first and well.
3. **Phase 2 - `dosclaw_qwen/config.py`, `dosclaw_qwen/model.py`** (DashScope chat model + `DashScopeTextEmbedding`
   per AGENTSCOPE_API.md), **`dosclaw_qwen/store.py`** (asyncpg + pgvector access), **`dosclaw_qwen/memory_service.py`**
   (plain `MemoryService` class - NOT a LongTermMemoryBase subclass - `recall`/`record`/`consolidate`,
   using ranking + store + embeddings + an LLM extract step), **`dosclaw_qwen/seed_embeddings.py`**.
4. **Phase 3 - `dosclaw_qwen/tools.py`** (`knowledge_search`, `human_handoff` returning `ToolResponse`;
   optional `search_memory` tool), **`dosclaw_qwen/agent.py`** (`Agent` + `Toolkit(tools=[FunctionTool(...)])`
   + the recall->observe->reply->record turn handler from AGENTSCOPE_API.md section 3).
5. **Phase 4 - `dosclaw_qwen/app.py`** (FastAPI: `/api/chat` SSE via `reply_stream`, emit a "memory recalled"
   block first then the reply; `/api/customers`, `/api/consolidate`; a simple demo-login cookie gate;
   serve `web/`), **`web/index.html`** (chat + customer selector + new-session + memory side-panel;
   render replies via DOM/textContent, never innerHTML).
6. **Phase 5 - local e2e** against live Qwen Cloud + local pgvector (needs `DASHSCOPE_API_KEY`):
   run the 5-step memory demo in the plan (returning customer recall, multi-customer isolation, handoff).
7. **Phase 6 - deploy on Alibaba** (Dockerfile python:3.11-slim; ECS + Dockerized Postgres, or RDS;
   adapt `scripts/`), then submission assets: architecture diagram, <3min video, devpost description,
   proof-of-Alibaba code link (`dosclaw_qwen/model.py` calls DashScope), testing access + demo login.

## Prerequisites you will need (the human, JOY, provides)

- **`DASHSCOPE_API_KEY`** (Qwen Cloud) - free via the $40 coupon form in `docs/hackathon-reference.md`.
  Needed only from Phase 5 onward; Phases 1-4 build without it.
- An **Alibaba Cloud account / ECS** for Phase 6 (JOY has an `aliyun` CLI + RAM user).

## Hard constraints

- Code, comments, docs, commits = **English**. The agent replies in the **customer's language**;
  the **demo runs in English** so global judges can follow (Qwen is multilingual).
- **Never commit secrets.** `.env.example` holds placeholders only; real keys live in `.env` (gitignored).
- Keep the repo **public + MIT-licensed** (hackathon requirement).
- The memory engine is the scored differentiator - do not fake it (the old attempt did; that is why it was replaced).
- Each git commit message body ends with:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

## Definition of done (hackathon deliverables)

Public repo (this one) with all source + setup instructions; text description; **proof of Alibaba
deployment** (link to `dosclaw_qwen/model.py` using DashScope + the live ECS URL); **architecture diagram**;
**<3-min demo video** (public) showing cross-session per-customer recall; track identified
(**MemoryAgent**); **testing access** (live URL + demo login). Optional blog post for the bonus prize.
