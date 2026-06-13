# DOSClaw-Qwen on Qwen Cloud - MemoryAgent - Design Spec

> Date: 2026-06-09
> Author: JOY + agent
> Status: Approved design (brainstorming output), pre-implementation
> Competition: Global AI Hackathon Series with Qwen Cloud (Devpost) - **MemoryAgent track**
> Deadline: 2026-07-09 14:00 PDT
> Supersedes: `docs/superpowers/plans/2026-06-08-qwen-cloud-dosclaw_qwen-submission.md` (the earlier
> OpenClaw/DOSClaw-based draft). This design uses **AgentScope** as the runtime instead.

## 1. Goal

Ship "DOSClaw-Qwen" - an SME customer-support agent with sophisticated, per-customer
persistent memory - as a Qwen Cloud hackathon entry in the MemoryAgent track. The agent
remembers each customer across sessions (preferences, profile, past orders, complaints),
recalls the right facts within a limited context window, forgets stale information, and
escalates to a human when it cannot resolve a request.

MemoryAgent track judging emphasizes: autonomous experience accumulation, efficient memory
storage/retrieval, timely forgetting of outdated info, and recalling critical memories in a
limited context window. The custom memory layer is the differentiator.

## 2. Non-goals

- Not forking QwenPaw or any existing assistant app (QwenPaw is a reference only; submitting a
  lightly-modified existing app would be weak on originality and is single-user, mismatched
  with our per-customer design).
- Not reusing the production DOSClaw/OpenClaw gateway, provisioning, multi-tenancy, or billing
  (private; judges do not need it). This is a clean standalone build.
- Not moving or touching the production DOSClaw fleet.
- Not a full SME ERP; scope is support chat + memory + knowledge + handoff.

## 3. Framework + stack (decided)

- **Runtime: AgentScope** (Alibaba open-source Python agent framework, Apache-2.0) - provides the
  agent loop, tool integration, MCP support, multi-session/multi-tenancy, and Alibaba-native
  deployment. QwenPaw (built on AgentScope) is a reference for wiring patterns only.
- **Model: Qwen Cloud (DashScope)** via the OpenAI-compatible endpoint
  (`https://dashscope-intl.aliyuncs.com/compatible-mode/v1`), latest Qwen chat model (exact id
  confirmed against the live model list at build time, not hardcoded from memory).
- **Embeddings: DashScope text-embedding** model (Qwen Cloud) for semantic memory.
- **Store: PostgreSQL + pgvector ON Alibaba Cloud.** The rule says the project "must be deployed
  on Alibaba Cloud infrastructure" and does NOT explicitly carve out the database, so to stay
  unambiguously compliant the DB lives on Alibaba too. Simplest: a Dockerized Postgres+pgvector
  container on the same demo ECS (no separate RDS cost/setup); Alibaba RDS for PostgreSQL is the
  managed alternative. We deliberately do NOT use external Supabase here, to avoid any
  "not on Alibaba" compliance risk.
- **Deploy: Alibaba Cloud** - a single ECS instance running the AgentScope app + web UI
  (simplest, clear "running on Alibaba" proof). Function Compute is an alternative.
- **Language: Python.** Public repo, Apache-2.0.

## 4. The memory model (the core differentiator)

Per-customer memory, keyed by `customer_id`. Two layers plus active maintenance:

### 4.1 Profile (structured, durable)
Stable, high-value facts about a customer: name, contact, language, stated preferences (e.g.
"prefers oat milk", "size M"), allergies/constraints, known products/orders. Stored as
structured rows (or a JSON document) per customer. Updated by a **memory writer**: after each
turn, an LLM step extracts durable facts; new facts that contradict old ones **replace** them
(conflict resolution), so the profile stays current.

### 4.2 Episodic (semantic, decaying)
Concise summaries of past interactions/events ("asked about return policy on 2026-05-02",
"complained about late delivery, resolved with coupon"). Each episode is embedded (DashScope)
into pgvector with metadata: timestamp, importance score (LLM-assigned), customer_id.

### 4.3 Retrieval - recall in a limited context window
Before responding, the **memory reader** assembles a compact memory block for THIS customer:
the full profile (small, always included) + the top-K episodic memories ranked by a blend of
semantic similarity to the current message and recency. Only this compact block is injected
into the prompt - demonstrating "recall critical memories within a limited context window"
rather than dumping the whole history.

### 4.4 Forgetting / consolidation - timely forgetting
Episodic memories carry a decay score (recency x importance). A consolidation pass (on write,
or periodic) summarizes clusters of old, low-importance episodes into the durable profile and
drops the raw episodes; superseded profile facts are overwritten. This keeps memory compact and
current and demonstrates "timely forgetting of outdated information".

### 4.5 Boundary
The `MemoryService` is a self-contained unit with a small interface: `write(customer_id, turn)`,
`recall(customer_id, query) -> memory_block`, `consolidate(customer_id)`. AgentScope's agent
calls `recall` before generating and `write` after each turn. The internals (DB, embeddings,
scoring) can change without touching the agent.

## 5. Components

- `dosclaw_qwen/agent.py` - the AgentScope agent: Qwen Cloud model + system persona (DOSClaw-Qwen,
  multilingual SME support, English demo) + tools, wired to `MemoryService`.
- `dosclaw_qwen/memory_service.py` - the hybrid MemoryService (section 4), backed by Postgres+pgvector.
- `dosclaw_qwen/tools/` - `knowledge_search` (shop FAQ via RAG over a small product/policy doc set) and
  `human_handoff` (escalates to a human queue; demo records the escalation + confirms only on
  success).
- `dosclaw_qwen/server.py` - web API (chat endpoint, streaming) + serves the UI.
- `web/` - single-page chat UI: a **customer selector (Customer A / B / ...)** and a **"new
  session" control** so a judge can play a returning customer and watch DOSClaw-Qwen recall their
  profile; an optional side panel shows the memory currently recalled (great for the track).
- `db/` - schema for `customers`, `customer_profile`, `episodic_memory` (pgvector), `knowledge`.
- Deploy: Alibaba ECS running the app + UI + a Dockerized Postgres+pgvector (or Alibaba RDS).
  Everything on Alibaba Cloud.

## 6. Data model (memory store)

- `customer_profile(customer_id, facts jsonb, updated_at)` - durable structured facts.
- `episodic_memory(id, customer_id, summary, embedding vector, importance real, created_at,
  last_recalled_at)` - decaying semantic episodes.
- `knowledge(id, title, content, embedding vector)` - shop FAQ for `knowledge_search`.
- `handoffs(id, customer_id, reason, created_at, status)` - escalation log.

## 7. Demo flow (for the video + judges)

1. Customer A: "Do you have oat-milk lattes? I'm lactose intolerant." DOSClaw-Qwen answers (knowledge),
   and the writer stores profile facts (lactose intolerant; likes oat milk).
2. New session, Customer A returns days later: "What do you recommend?" DOSClaw-Qwen RECALLS the
   profile and proactively suggests oat-milk options - cross-session, per-customer recall.
3. Customer B (different memory) asks something - shows multi-customer isolation.
4. A complaint DOSClaw-Qwen cannot resolve -> `human_handoff` -> confirms escalation.
5. (Optional) Show the consolidation/forgetting: an old trivial episode is summarized away while
   the durable preference persists.

## 8. Deliverables (submission)

- Public open-source repo (Apache-2.0) with all source + setup instructions.
- Proof of Alibaba Cloud deployment (short recording showing the backend on Alibaba).
- Architecture diagram.
- ~3-minute demo video (public on YouTube/Vimeo).
- Uses Qwen Cloud API (DashScope) + deployed on Alibaba Cloud.

## 9. Scope (MVP vs stretch)

**MVP:** the hybrid MemoryService (profile + episodic + recall + basic forgetting), the DOSClaw-Qwen
agent on Qwen Cloud via AgentScope, `knowledge_search` + `human_handoff` tools, the web chat UI
with customer selector + new-session, deployed on Alibaba Cloud with a seeded demo shop + 2-3
demo customers.

**Stretch:** the memory side-panel visualization, a periodic consolidation job, an eval of recall
quality, and an extra channel (Telegram/DingTalk) reusing AgentScope's channel support.

## 10. Risks / prerequisites

- **Prerequisites (confirm before build):** an Alibaba Cloud account (ECS + RDS or Docker) and a
  Qwen Cloud / DashScope API key. JOY to confirm availability; grep vault/memory first.
- AgentScope 2.0 API + memory primitives: confirm against current docs at build (do not assume).
- Exact Qwen Cloud chat + embedding model ids: confirm against the live DashScope model list.
- DB on Alibaba (Dockerized Postgres+pgvector on the ECS, or RDS) - chosen for unambiguous
  compliance with "must be deployed on Alibaba Cloud infrastructure" (the DB carve-out is not
  spelled out, so keeping it on Alibaba is the safe read). Qwen Cloud provides a $40 coupon,
  which covers the DashScope key prerequisite.
- Deadline is comfortable (2026-07-09); build unhurried, MVP first.

## 11. Why this wins the track

It targets MemoryAgent's exact criteria with a real product story: per-customer durable +
episodic memory, semantic+recency recall into a limited context, and active forgetting/
consolidation - all on the idiomatic Qwen Cloud + AgentScope + Alibaba stack, with a demo that
makes cross-session, multi-customer recall visible.
