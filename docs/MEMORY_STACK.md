# Memory Stack Decision - AgentScope 2.0 + Mem0Middleware (PR #1775) + custom layer

> Decided 2026-06-13. DOSClaw-Qwen runs on AgentScope **2.0** and gets long-term memory from the
> **`Mem0Middleware`** that is in-flight upstream as **PR #1775** (mem0-backed; routes mem0 through
> OUR AgentScope Qwen model, so no OpenAI key). We add a thin custom layer on top and contribute a
> DOSClaw-Qwen example back upstream. This SUPERSEDES the earlier "hand-roll mem0 + pgvector" approach
> and §5 of AGENTSCOPE_API.md.

## Why this (the journey, with evidence)

- AgentScope 2.0 dropped 1.x's `Mem0LongTermMemory`. Per the official FAQ, RAG + long-term memory
  are *"being ported from 1.0 to the 2.0 architecture and will land in upcoming releases"*
  (https://docs.agentscope.io/v2/others/faq). So 2.0.x has no built-in long-term memory yet.
- In 2.0 the idiomatic home for memory is a **middleware** (`Agent(middlewares=[...])`).
- **PR #1775** "feat(middleware): add mem0-backed long-term memory middleware" (OPEN, MERGEABLE,
  53 tests, author Osier-Yi, fork branch `mem0-dev`, base `main`) already implements exactly this.
  Its `_agentscope_adapter.py` (`AgentScopeLLM` / `AgentScopeEmbedding` + `build_mem0_config`) makes
  mem0 use OUR AgentScope chat + embedding model for extraction/embeddings - **mem0 runs on
  Qwen/DashScope, no separate OpenAI key.** This is what makes the hackathon's Qwen-only rule work.
- So we do NOT hand-roll memory and do NOT pin to 1.x.
  Rejected: honcho (AGPL-3.0), pin-1.0.21 (works but old + no contribution story), opening our own
  mem0 PR (would duplicate #1775).

## How DOSClaw-Qwen uses it

1. Install AgentScope 2.0 with the middleware. Until PR #1775 merges, install from the PR branch:
   `pip install "agentscope[mem0] @ git+https://github.com/Osier-Yi/agentscope.git@mem0-dev"`
   (mem0ai>=2.0.0,<3.0.0). Switch to released `agentscope[mem0]` once #1775 merges.
2. Build the agent following PR #1775's example `examples/middleware/longterm_memory/mem0/oss_demo.py`
   + its README (READ THEM - they are the source of truth for the constructor):
   - DashScope chat model per AGENTSCOPE_API.md §2/§3:
     `DashScopeChatModel(credential=DashScopeCredential(api_key=...), model=..., stream=True, formatter=DashScopeChatFormatter())`.
   - `Mem0Middleware(...)` configured via `build_mem0_config` so mem0's LLM + embeddings are the
     AgentScope DashScope model (NO OpenAI). Choose a vector store (pgvector or mem0's default local).
   - `Agent(name="DOSClaw-Qwen", system_prompt=..., model=..., toolkit=..., middlewares=[mem0_mw])` with the
     middleware's mode = one of `static_control` (auto search-before-reply + write-after),
     `agent_control` (`search_memory`/`add_memory` tools), or `both` (default).
   - Per-customer isolation: scope memory by `user_id = customer_id` (confirm how #1775 threads the
     user/agent id - read `_middleware.py`).
3. mem0 owns episodic storage. We keep a relational `customer_profile` / `knowledge` / `handoffs` in
   Postgres for the structured profile + FAQ RAG + handoff log (NOT episodic - mem0 has that).

## What stays custom (our Innovation / Technical-Depth on top of the middleware)

1. Structured per-customer **profile** (conflict-overwrite) beyond mem0's flat facts - shown in a UI panel.
2. **Recall composition in limited context**: combine the profile + mem0 search hits into a compact
   block (static_control already injects mem0 hits; we add the profile + light ranking).
3. Optional **persona layering** idea (L0 conversation -> L1 atom -> L2 scenario -> L3 persona)
   borrowed as a design concept (inspiration only, no code copied).
4. `knowledge_search` (shop FAQ RAG via DashScope `text-embedding-v4`) + `human_handoff` tools.
5. The **memory side-panel** UI visualizing what was recalled each turn (strong for the demo).

## Our upstream contribution (honest, NON-duplicate)

Do NOT open a duplicate mem0 PR (#1775 already does it). Instead:
- Contribute a **DOSClaw-Qwen example** (VN SME multi-customer support agent, multi-`user_id`) to
  `examples/middleware/longterm_memory/` on top of #1775 - examples are welcome and non-duplicative.
- Use #1775 in a real app and give feedback / review / small fixes on the PR (genuine engagement).
- Align with the official port tracking issues (the unified RAG + long-term-memory abstraction:
  IS #1663; related #1665 / #1747). Reference them in our writeup.
This yields a truthful "contributed to AgentScope 2.0's memory effort" story without claiming to be first.

## Confirm before coding (read the PR, do not guess)

- Read PR #1775 files: `_middleware.py` (modes + how user_id/agent_id is threaded),
  `_agentscope_adapter.py` (`build_mem0_config` exact signature), `_tools.py`, and
  `examples/middleware/longterm_memory/mem0/oss_demo.py`.
- Confirm the `Mem0Middleware` constructor (how to pass the AgentScope model + the vector store).
- Confirm the per-customer key (`user_id`) flows through so Customer A and B stay isolated.
- Confirm `mem0ai` version (PR pins `>=2.0.0,<3.0.0`).

## Verified Mem0Middleware API + multi-tenant keying (read from PR #1775, 2026-06-13)

**Constructor** (`_middleware.py`):
```python
Mem0Middleware(
    user_id: str,                 # REQUIRED, mem0 namespacing -> use the CUSTOMER id
    chat_model=...,               # AgentScope chat model mem0 uses for extraction (DashScope/Qwen)
    embedding_model=...,          # AgentScope embedding model mem0 uses (DashScope)
    mem0_config=None,             # optional full mem0 config (takes precedence; for a pgvector store)
    mode="both",                  # "static_control" | "agent_control" | "both" (default "both")
    agent_id: str | None = None,  # optional finer-grained scoping -> use the TENANT (shop) id
)
```

**Multi-tenant + multi-customer = NATIVE (no custom keying code needed).** mem0 scopes memories by
`(user_id, agent_id)`:
- `user_id = customer_id`  -> per-customer isolation (Customer A vs Customer B).
- `agent_id = tenant_id`   -> per-shop isolation (Shop X vs Shop Y).
- Build one `Mem0Middleware(user_id=customer_id, agent_id=tenant_id, ...)` per (tenant, customer)
  session. **Demo = ONE tenant + many customers; architecture already supports M tenants.**

**Verified 2.0 wiring** (from `examples/middleware/longterm_memory/mem0/oss_demo.py`):
```python
from agentscope.agent import Agent
from agentscope.credential import DashScopeCredential
from agentscope.model import DashScopeChatModel
from agentscope.embedding import DashScopeEmbeddingModel   # 2.0 NAME (NOT 1.0's DashScopeTextEmbedding)
from agentscope.formatter import DashScopeChatFormatter
from agentscope.middleware import Mem0Middleware
from agentscope.tool import Toolkit
from agentscope.message import UserMsg
from agentscope.event import (ReplyStartEvent, TextBlockDeltaEvent,
    ToolCallStartEvent, ToolCallDeltaEvent, ToolResultTextDeltaEvent, ToolResultEndEvent)

chat = DashScopeChatModel(credential=DashScopeCredential(api_key=KEY), model="qwen-plus",
                          stream=True, formatter=DashScopeChatFormatter())
emb  = DashScopeEmbeddingModel(...)   # CONFIRM ctor: DashScope text-embedding-v4, dim 1024, int'l base url
mw   = Mem0Middleware(user_id=customer_id, agent_id=tenant_id,
                      chat_model=chat, embedding_model=emb, mode="both")
agent = Agent(name="DOSClaw-Qwen", system_prompt=SYS, model=chat, toolkit=toolkit, middlewares=[mw])

async for ev in agent.reply_stream(inputs=UserMsg(name="user", content=text, role="user")):
    # ReplyStartEvent: middleware has ALREADY appended a name="memory" hint msg to agent.state.context
    #   (static_control) -> read it for the "memory recalled" UI panel.
    # TextBlockDeltaEvent: stream the reply text to the browser (SSE).
    # ToolCall*/ToolResult*: search_memory / add_memory activity (agent_control).
    ...
```
- `static_control` searches mem0 before reply + appends a `name="memory"` hint msg to
  `agent.state.context`, writes the exchange back after. `agent_control` exposes `search_memory` /
  `add_memory` tools. `both` = both.
- mem0 store: default Qdrant; for pgvector pass a `mem0_config`/`VectorStoreConfig`
  (`mem0.configs.base.MemoryConfig`, `mem0.vector_stores.configs.VectorStoreConfig`).

**Relational schema change (do this in `db/schema.sql`):** mem0 OWNS episodic memory now, so
**drop the `episodic_memory` table**. Add a `tenants` table and a `tenant_id` column on `customers`,
`customer_profile`, `knowledge` (per-tenant FAQ), `handoffs`. Seed ONE tenant (the demo shop) + 2-3
customers under it. `knowledge_search` filters by `tenant_id`.
