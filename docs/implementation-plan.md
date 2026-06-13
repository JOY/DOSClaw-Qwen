# DOSClaw-Qwen on Qwen Cloud (MemoryAgent) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build "DOSClaw-Qwen" - an SME customer-support agent with per-customer persistent memory - on AgentScope 2.0 + Qwen Cloud (DashScope), deployed on Alibaba Cloud, as a MemoryAgent-track hackathon entry.

**Architecture:** An AgentScope `ReActAgent` (Qwen `qwen3.6-plus` via `DashScopeChatModel`) whose persistence comes from a CUSTOM `LongTermMemoryBase` subclass (`DOSClaw-QwenMemory`) implementing a hybrid per-customer memory: a structured profile + decaying episodic memory in Postgres+pgvector, with semantic+recency recall into a compact context block and active forgetting/consolidation. Tools: `knowledge_search` (shop FAQ RAG) and `human_handoff`. Served via FastAPI with a web chat UI (customer selector + new-session). Everything (app + Postgres) runs on an Alibaba ECS instance; DashScope (Qwen Cloud) is the model/embedding API.

**Tech Stack:** Python 3.11+, AgentScope 2.0 (`agentscope`), DashScope (`qwen3.6-plus` chat + `text-embedding-v4`), Postgres + pgvector, `asyncpg`, FastAPI + uvicorn, Docker, Alibaba ECS.

**Verified API reference (mid-2026):** see `docs/hackathons/qwen-cloud-2026/hackathon-reference.md` and the AgentScope/DashScope notes embedded in the tasks below (sourced from doc.agentscope.io + Alibaba Model Studio docs). Confirm exact AgentScope 2.0 symbols against the installed package at build time (it is new).

---

## File Structure

```
apps/dosclaw_qwen-qwen/                  # NEW standalone app (in DOS-AI repo; public repo extracted at the end)
  requirements.txt
  Dockerfile
  docker-compose.yml              # app + postgres(pgvector) for local + ECS
  .env.example
  dosclaw_qwen/
    __init__.py
    config.py                     # env: DASHSCOPE_API_KEY, DASHSCOPE_BASE_URL, DATABASE_URL, model ids
    model.py                      # DashScopeChatModel factory + embeddings client
    ranking.py                    # PURE memory math: recall ranking, decay, conflict merge (unit-tested)
    store.py                      # Postgres+pgvector access (asyncpg): profile, episodic, knowledge, handoffs
    memory.py                     # DOSClaw-QwenMemory(LongTermMemoryBase): record/retrieve + writer + consolidation
    tools.py                      # knowledge_search + human_handoff tool functions
    agent.py                      # build_agent(customer_id) -> ReActAgent
    app.py                        # FastAPI: /api/chat (SSE), /api/customers, serves web/
  web/
    index.html                    # chat UI: customer selector + new-session + memory side-panel
  db/
    schema.sql                    # dosclaw_qwen schema + tables (pgvector)
    seed.sql                      # demo shop FAQ + 2-3 customers (some with prior memory)
  tests/
    test_ranking.py               # pure unit tests (no DB/LLM)
  infra/alibaba/
    README.md                     # ECS + docker-compose deploy steps (proof of Alibaba)
  README.md                       # for the public repo
  ARCHITECTURE.md
```

---

## Phase 0 - Setup

### Task 0.1: Worktree + scaffold

- [ ] **Step 1: Worktree off `dev`** (repo rule: never branch-switch the shared checkout)
```bash
cd D:/Projects/DOS-AI && git fetch origin dev && git worktree add -b feat/dosclaw_qwen-qwen ../DOS-AI-dosclaw_qwen origin/dev
```
All paths below are relative to `../DOS-AI-dosclaw_qwen`.

- [ ] **Step 2: Create dirs + `requirements.txt`**
```bash
mkdir -p apps/dosclaw_qwen-qwen/dosclaw_qwen apps/dosclaw_qwen-qwen/web apps/dosclaw_qwen-qwen/db apps/dosclaw_qwen-qwen/tests apps/dosclaw_qwen-qwen/infra/alibaba
```
`apps/dosclaw_qwen-qwen/requirements.txt`:
```
agentscope>=2.0.1
openai>=1.40.0
asyncpg>=0.30.0
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
python-dotenv>=1.0.1
pytest>=8.0.0
pytest-asyncio>=0.24.0
```
(Note: `agentscope-runtime` is the heavier serving layer; this plan uses plain FastAPI driving `await agent(msg)` for a lean, demoable service. Add `agentscope-runtime` only if multi-tenant session durability is needed as a stretch.)

- [ ] **Step 3: `.env.example`**
```
DASHSCOPE_API_KEY=<your-qwen-cloud-key>
DASHSCOPE_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1
QWEN_CHAT_MODEL=qwen3.6-plus
QWEN_EMBED_MODEL=text-embedding-v4
EMBED_DIM=1024
DATABASE_URL=postgresql://dosclaw_qwen:dosclaw_qwen@localhost:5432/dosclaw_qwen
DEMO_LOGIN_USER=judge
DEMO_LOGIN_PASS=<random>
```

- [ ] **Step 4: Commit scaffold**
```bash
git add apps/dosclaw_qwen-qwen/requirements.txt apps/dosclaw_qwen-qwen/.env.example
git commit -m "feat(dosclaw_qwen): scaffold AgentScope Qwen MemoryAgent app

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 0.2: Postgres + pgvector (local + on-Alibaba) and schema

- [ ] **Step 1: `docker-compose.yml`** (a pgvector Postgres; the app joins it - same compose runs on the Alibaba ECS)
```yaml
services:
  db:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_USER: dosclaw_qwen
      POSTGRES_PASSWORD: dosclaw_qwen
      POSTGRES_DB: dosclaw_qwen
    ports: ["5432:5432"]
    volumes: ["pgdata:/var/lib/postgresql/data", "./db:/docker-entrypoint-initdb.d"]
volumes: { pgdata: {} }
```

- [ ] **Step 2: `db/schema.sql`**
```sql
create extension if not exists vector;

create table if not exists customers (
  id text primary key,            -- demo: 'cust_a', 'cust_b'
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists customer_profile (
  customer_id text primary key references customers(id),
  facts jsonb not null default '{}'::jsonb,   -- {"prefers":"oat milk","allergy":"lactose",...}
  updated_at timestamptz not null default now()
);

create table if not exists episodic_memory (
  id bigint generated always as identity primary key,
  customer_id text not null references customers(id),
  summary text not null,
  embedding vector(1024) not null,
  importance real not null default 0.5,       -- 0..1, LLM-assigned
  created_at timestamptz not null default now(),
  last_recalled_at timestamptz
);
create index if not exists episodic_cust_idx on episodic_memory(customer_id);
create index if not exists episodic_vec_idx on episodic_memory using ivfflat (embedding vector_cosine_ops) with (lists = 100);

create table if not exists knowledge (
  id bigint generated always as identity primary key,
  title text not null,
  content text not null,
  embedding vector(1024) not null
);
create index if not exists knowledge_vec_idx on knowledge using ivfflat (embedding vector_cosine_ops) with (lists = 50);

create table if not exists handoffs (
  id bigint generated always as identity primary key,
  customer_id text not null,
  reason text not null,
  created_at timestamptz not null default now(),
  status text not null default 'open'
);
```

- [ ] **Step 3: `db/seed.sql`** (demo shop "Bloom Cafe" + 2 customers; A has prior memory, B is new)
```sql
insert into customers (id, name) values ('cust_a','Returning Customer A'), ('cust_b','New Customer B')
  on conflict (id) do nothing;
insert into customer_profile (customer_id, facts) values
  ('cust_a', '{"name":"Linh","lactose_intolerant":true,"prefers":"oat milk lattes","last_order":"oat latte + almond croissant"}')
  on conflict (customer_id) do update set facts = excluded.facts, updated_at = now();
-- episodic + knowledge rows are inserted by a seed script (Task 2.4) because they need embeddings.
```
- [ ] **Step 4: Commit**
```bash
git add apps/dosclaw_qwen-qwen/docker-compose.yml apps/dosclaw_qwen-qwen/db/schema.sql apps/dosclaw_qwen-qwen/db/seed.sql
git commit -m "feat(dosclaw_qwen): postgres+pgvector schema and base seed

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 1 - Memory math (pure, TDD)

### Task 1.1: `dosclaw_qwen/ranking.py` - recall ranking, decay, profile merge (TDD)

**Files:** Create `apps/dosclaw_qwen-qwen/dosclaw_qwen/ranking.py`; Test `apps/dosclaw_qwen-qwen/tests/test_ranking.py`.

- [ ] **Step 1: Write the failing test** `tests/test_ranking.py`
```python
from dosclaw_qwen.ranking import rank_episodes, decay_score, merge_profile

def test_rank_blends_similarity_and_recency():
    eps = [
        {"id": 1, "similarity": 0.9, "age_days": 30, "importance": 0.5},  # relevant but old
        {"id": 2, "similarity": 0.6, "age_days": 0,  "importance": 0.5},  # fresh, less relevant
        {"id": 3, "similarity": 0.2, "age_days": 1,  "importance": 0.1},  # noise
    ]
    top = rank_episodes(eps, k=2)
    assert [e["id"] for e in top] == [1, 2]          # 3 is dropped
    assert all("score" in e for e in top)

def test_decay_score_drops_with_age_rises_with_importance():
    assert decay_score(importance=0.9, age_days=0) > decay_score(importance=0.9, age_days=60)
    assert decay_score(importance=0.9, age_days=10) > decay_score(importance=0.1, age_days=10)

def test_merge_profile_overrides_conflicts():
    old = {"prefers": "cow milk", "size": "M"}
    new = {"prefers": "oat milk"}
    merged = merge_profile(old, new)
    assert merged == {"prefers": "oat milk", "size": "M"}   # new overrides, others kept
```

- [ ] **Step 2: Run, verify it fails**
Run: `cd apps/dosclaw_qwen-qwen && python -m pytest tests/test_ranking.py -v` -> FAIL (module not found).

- [ ] **Step 3: Implement `dosclaw_qwen/ranking.py`**
```python
"""Pure, dependency-free memory math: ranking, decay, profile merge. Unit-tested."""
from __future__ import annotations
import math


def decay_score(importance: float, age_days: float, half_life_days: float = 21.0) -> float:
    """Memory strength = importance * exponential recency decay (half-life ~3 weeks)."""
    recency = math.pow(0.5, age_days / half_life_days)
    return max(0.0, min(1.0, importance)) * recency


def rank_episodes(episodes: list[dict], k: int = 5, min_score: float = 0.15) -> list[dict]:
    """Blend semantic similarity with recency*importance, return top-k above min_score.

    Each episode dict needs: similarity (0..1), age_days, importance (0..1).
    """
    scored = []
    for e in episodes:
        strength = decay_score(e.get("importance", 0.5), e.get("age_days", 0.0))
        score = 0.7 * e.get("similarity", 0.0) + 0.3 * strength
        scored.append({**e, "score": score})
    scored = [e for e in scored if e["score"] >= min_score]
    scored.sort(key=lambda e: e["score"], reverse=True)
    return scored[:k]


def merge_profile(old: dict, new: dict) -> dict:
    """Merge extracted profile facts: new keys override conflicting old keys; others kept."""
    merged = dict(old)
    for key, value in new.items():
        if value is None or value == "":
            merged.pop(key, None)        # explicit null forgets the fact
        else:
            merged[key] = value
    return merged
```

- [ ] **Step 4: Run, verify it passes**
Run: `python -m pytest tests/test_ranking.py -v` -> PASS (3 tests).

- [ ] **Step 5: Commit**
```bash
git add apps/dosclaw_qwen-qwen/dosclaw_qwen/ranking.py apps/dosclaw_qwen-qwen/tests/test_ranking.py
git commit -m "feat(dosclaw_qwen): pure memory ranking/decay/profile-merge (TDD)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2 - Model, store, memory service

### Task 2.1: `dosclaw_qwen/config.py` + `dosclaw_qwen/model.py`

- [ ] **Step 1: `dosclaw_qwen/config.py`**
```python
import os
from dotenv import load_dotenv
load_dotenv()

DASHSCOPE_API_KEY = os.environ.get("DASHSCOPE_API_KEY", "")
DASHSCOPE_BASE_URL = os.environ.get("DASHSCOPE_BASE_URL", "https://dashscope-intl.aliyuncs.com/compatible-mode/v1")
QWEN_CHAT_MODEL = os.environ.get("QWEN_CHAT_MODEL", "qwen3.6-plus")
QWEN_EMBED_MODEL = os.environ.get("QWEN_EMBED_MODEL", "text-embedding-v4")
EMBED_DIM = int(os.environ.get("EMBED_DIM", "1024"))
DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://dosclaw_qwen:dosclaw_qwen@localhost:5432/dosclaw_qwen")
```

- [ ] **Step 2: `dosclaw_qwen/model.py`** (chat model factory + embeddings)
```python
"""Qwen Cloud (DashScope) wiring: AgentScope chat model + OpenAI-compatible embeddings."""
from openai import AsyncOpenAI
from agentscope.model import DashScopeChatModel
from agentscope.formatter import DashScopeChatFormatter
from . import config

def make_chat_model() -> DashScopeChatModel:
    return DashScopeChatModel(
        model_name=config.QWEN_CHAT_MODEL,
        api_key=config.DASHSCOPE_API_KEY,
        stream=True,
    )

def make_formatter() -> DashScopeChatFormatter:
    return DashScopeChatFormatter()

_embed_client = AsyncOpenAI(api_key=config.DASHSCOPE_API_KEY, base_url=config.DASHSCOPE_BASE_URL)

async def embed(text: str) -> list[float]:
    resp = await _embed_client.embeddings.create(
        model=config.QWEN_EMBED_MODEL, input=text, dimensions=config.EMBED_DIM,
    )
    return resp.data[0].embedding
```
- [ ] **Step 3:** Verify imports against the installed package: `python -c "from agentscope.model import DashScopeChatModel; from agentscope.formatter import DashScopeChatFormatter"`. If a symbol differs in the installed 2.0.x, adjust to the real name (check `python -c "import agentscope.model as m; print(dir(m))"`). Commit.

### Task 2.2: `dosclaw_qwen/store.py` - Postgres+pgvector access (asyncpg)

- [ ] **Step 1: Implement `dosclaw_qwen/store.py`** with an async pool and these functions (vectors passed as the pgvector string form `'[...]'`):
```python
import json
import asyncpg
from . import config

_pool: asyncpg.Pool | None = None

async def pool() -> asyncpg.Pool:
    global _pool
    if _pool is None:
        _pool = await asyncpg.create_pool(config.DATABASE_URL, min_size=1, max_size=5)
    return _pool

def _vec(v: list[float]) -> str:
    return "[" + ",".join(repr(float(x)) for x in v) + "]"

async def get_profile(customer_id: str) -> dict:
    p = await pool()
    row = await p.fetchrow("select facts from customer_profile where customer_id=$1", customer_id)
    return dict(row["facts"]) if row and row["facts"] else {}

async def set_profile(customer_id: str, facts: dict) -> None:
    p = await pool()
    await p.execute(
        """insert into customer_profile(customer_id, facts, updated_at) values($1,$2,now())
           on conflict (customer_id) do update set facts=excluded.facts, updated_at=now()""",
        customer_id, json.dumps(facts),
    )

async def add_episode(customer_id: str, summary: str, embedding: list[float], importance: float) -> None:
    p = await pool()
    await p.execute(
        """insert into episodic_memory(customer_id, summary, embedding, importance)
           values($1,$2,$3::vector,$4)""",
        customer_id, summary, _vec(embedding), importance,
    )

async def search_episodes(customer_id: str, query_embedding: list[float], limit: int = 20) -> list[dict]:
    p = await pool()
    rows = await p.fetch(
        """select id, summary, importance,
                  1 - (embedding <=> $2::vector) as similarity,
                  extract(epoch from (now()-created_at))/86400.0 as age_days
           from episodic_memory where customer_id=$1
           order by embedding <=> $2::vector limit $3""",
        customer_id, _vec(query_embedding), limit,
    )
    return [dict(r) for r in rows]

async def search_knowledge(query_embedding: list[float], limit: int = 3) -> list[dict]:
    p = await pool()
    rows = await p.fetch(
        """select title, content, 1-(embedding <=> $1::vector) as similarity
           from knowledge order by embedding <=> $1::vector limit $2""",
        _vec(query_embedding), limit,
    )
    return [dict(r) for r in rows]

async def log_handoff(customer_id: str, reason: str) -> int:
    p = await pool()
    return await p.fetchval(
        "insert into handoffs(customer_id, reason) values($1,$2) returning id", customer_id, reason)
```
- [ ] **Step 2: Smoke test** against the local Docker DB (after `docker compose up -d db` + applying schema): a tiny script inserts a profile + episode and reads them back. Confirm pgvector `<=>` works. Commit.

### Task 2.3: `dosclaw_qwen/memory.py` - `DOSClaw-QwenMemory(LongTermMemoryBase)`

> AgentScope 2.0: subclass `agentscope.memory.LongTermMemoryBase`; implement `record(msgs)`, `retrieve(msg)->str`, and the agent-control tool methods `record_to_memory(content)->str`, `retrieve_from_memory(query)->str`. Attach via `ReActAgent(long_term_memory=..., long_term_memory_mode=...)`. Confirm the exact base-class method signatures against the installed package before finalizing.

- [ ] **Step 1: Implement `dosclaw_qwen/memory.py`**
```python
"""Per-customer hybrid memory: structured profile + decaying episodic, with semantic+recency
recall and forgetting/consolidation. Implements AgentScope's LongTermMemoryBase."""
import json
from agentscope.memory import LongTermMemoryBase
from agentscope.message import Msg
from . import store, model
from .ranking import rank_episodes, merge_profile

# An LLM prompt that extracts durable profile facts + an episodic summary + importance from a turn.
_EXTRACT_SYS = (
    "You extract durable customer memory from a support conversation turn. "
    "Return STRICT JSON: {\"profile\": {<stable facts to remember, e.g. preferences, allergies, "
    "name>}, \"episode\": \"one-sentence summary of what happened\", \"importance\": 0.0-1.0}. "
    "profile may be empty {} if nothing durable. Use null as a value to forget a fact."
)

class DOSClaw-QwenMemory(LongTermMemoryBase):
    def __init__(self, customer_id: str):
        super().__init__()
        self.customer_id = customer_id

    async def _extract(self, text: str) -> dict:
        from openai import AsyncOpenAI
        from . import config
        client = AsyncOpenAI(api_key=config.DASHSCOPE_API_KEY, base_url=config.DASHSCOPE_BASE_URL)
        resp = await client.chat.completions.create(
            model=config.QWEN_CHAT_MODEL,
            messages=[{"role": "system", "content": _EXTRACT_SYS},
                      {"role": "user", "content": text}],
            response_format={"type": "json_object"},
        )
        try:
            return json.loads(resp.choices[0].message.content)
        except Exception:
            return {"profile": {}, "episode": "", "importance": 0.3}

    async def _write(self, text: str) -> None:
        data = await self._extract(text)
        prof = data.get("profile") or {}
        if prof:
            merged = merge_profile(await store.get_profile(self.customer_id), prof)
            await store.set_profile(self.customer_id, merged)
        episode = (data.get("episode") or "").strip()
        if episode:
            emb = await model.embed(episode)
            await store.add_episode(self.customer_id, episode, emb, float(data.get("importance", 0.4)))

    async def _recall_block(self, query: str) -> str:
        profile = await store.get_profile(self.customer_id)
        q_emb = await model.embed(query)
        candidates = await store.search_episodes(self.customer_id, q_emb, limit=20)
        top = rank_episodes(candidates, k=5)
        lines = []
        if profile:
            lines.append("Customer profile: " + json.dumps(profile, ensure_ascii=False))
        if top:
            lines.append("Relevant past memories:")
            lines += [f"- {e['summary']}" for e in top]
        return "\n".join(lines) if lines else ""

    # --- LongTermMemoryBase interface (static-control) ---
    async def record(self, msgs: list[Msg]) -> None:
        for m in msgs:
            content = m.content if isinstance(m.content, str) else str(m.content)
            if content:
                await self._write(content)

    async def retrieve(self, msg: Msg) -> str:
        query = msg.content if isinstance(msg.content, str) else str(msg.content)
        return await self._recall_block(query)

    # --- agent-control tool methods ---
    async def record_to_memory(self, content: str) -> str:
        await self._write(content)
        return "Saved to long-term memory."

    async def retrieve_from_memory(self, query: str) -> str:
        block = await self._recall_block(query)
        return block or "No relevant memories."
```

- [ ] **Step 2: Consolidation/forgetting helper** (append to `dosclaw_qwen/memory.py`): a method `consolidate()` that drops episodes whose `decay_score` is below a floor after summarizing the customer's durable takeaways into the profile. (Demo can call it via a `/api/consolidate` admin route or a button.)
```python
    async def consolidate(self, floor: float = 0.1) -> int:
        """Forget faded episodes (low decay score). Returns count removed."""
        from .ranking import decay_score
        import asyncpg  # noqa
        p = await store.pool()
        rows = await p.fetch(
            """select id, importance, extract(epoch from (now()-created_at))/86400.0 as age_days
               from episodic_memory where customer_id=$1""", self.customer_id)
        stale = [r["id"] for r in rows if decay_score(r["importance"], r["age_days"]) < floor]
        if stale:
            await p.execute("delete from episodic_memory where id = any($1::bigint[])", stale)
        return len(stale)
```
- [ ] **Step 3: Commit.** (No unit test here - it is integration; the pure logic it relies on is tested in Task 1. A live smoke happens in Task 5.)

### Task 2.4: Seed script for embeddings (FAQ + episodic for cust_a)

- [ ] **Step 1: `dosclaw_qwen/seed_embeddings.py`** - a script that inserts shop FAQ rows (e.g. opening hours, return policy, menu, allergy info) and a couple of past episodes for `cust_a` (e.g. "Linh asked for dairy-free options on 2026-05") with real embeddings via `model.embed`. Run it after `schema.sql` + `seed.sql`. Commit.

---

## Phase 3 - Tools + agent

### Task 3.1: `dosclaw_qwen/tools.py` - knowledge_search + human_handoff

- [ ] **Step 1: Implement** (plain async functions with type hints + docstrings; registered via `Toolkit.register_tool_function`):
```python
"""Agent tools. Type hints + docstrings drive AgentScope's auto JSON-schema."""
from . import store, model

async def knowledge_search(query: str) -> str:
    """Search the shop's FAQ / policy / menu knowledge base.

    Args:
        query: what the customer is asking about (e.g. 'return policy', 'dairy-free').
    Returns:
        The most relevant knowledge snippets, or a note if nothing matches.
    """
    emb = await model.embed(query)
    hits = await store.search_knowledge(emb, limit=3)
    if not hits:
        return "No matching shop information found."
    return "\n\n".join(f"{h['title']}: {h['content']}" for h in hits)

def make_human_handoff(customer_id: str):
    async def human_handoff(reason: str) -> str:
        """Escalate to a human agent when you cannot resolve the request (refunds, complaints,
        anything outside policy). Only confirm escalation after this returns success.

        Args:
            reason: a short summary of why a human is needed.
        """
        hid = await store.log_handoff(customer_id, reason)
        return f"Escalated to a human agent (ticket #{hid}). A teammate will follow up."
    return human_handoff
```
- [ ] **Step 2: Commit.**

### Task 3.2: `dosclaw_qwen/agent.py` - build the ReActAgent

- [ ] **Step 1: Implement**
```python
from agentscope.agent import ReActAgent
from agentscope.memory import InMemoryMemory
from agentscope.tool import Toolkit
from . import model, tools
from .memory import DOSClaw-QwenMemory

SYS_PROMPT = (
    "Ban la DOSClaw-Qwen, tro ly cham soc khach hang cua mot shop. Tra loi bang dung ngon ngu khach "
    "dung (tieng Viet thi co dau day du), ngan gon, than thien. Dung knowledge_search cho cau hoi "
    "ve san pham/chinh sach. Khi gap viec ngoai chinh sach (hoan tien, khieu nai phuc tap) PHAI "
    "goi human_handoff. Khi khach quay lai, dung bo nho da co de ca nhan hoa - dung hoi lai dieu "
    "da biet. Tuyet doi khong bia thong tin."
)

def build_agent(customer_id: str) -> ReActAgent:
    toolkit = Toolkit()
    toolkit.register_tool_function(tools.knowledge_search)
    toolkit.register_tool_function(tools.make_human_handoff(customer_id))
    return ReActAgent(
        name="DOSClaw-Qwen",
        sys_prompt=SYS_PROMPT,
        model=model.make_chat_model(),
        formatter=model.make_formatter(),
        toolkit=toolkit,
        memory=InMemoryMemory(),                         # short-term, this session
        long_term_memory=DOSClaw-QwenMemory(customer_id),       # per-customer persistent
        long_term_memory_mode="both",                    # agent can record/recall AND we retrieve
    )
```
- [ ] **Step 2:** Confirm `ReActAgent` accepts `long_term_memory` + `long_term_memory_mode` in the installed 2.0.x (the research found these; verify `python -c "import inspect,agentscope.agent as a; print(inspect.signature(a.ReActAgent.__init__))"`). Adjust kwarg names if needed. Commit.

---

## Phase 4 - Web service + UI

### Task 4.1: `dosclaw_qwen/app.py` - FastAPI chat service

- [ ] **Step 1: Implement** `/api/chat` (streams the agent's reply + a recalled-memory block), `/api/customers`, `/api/consolidate`, static serving, and a simple login gate (reuse the cookie pattern from the bexly-coach app: a `/login` page that pre-fills demo creds, sets a cookie; gate `/` and `/api/*`). Drive the agent with `await agent(Msg(...))`; build a fresh agent per (customer_id) per request (memory is in the DB, so statelessness is fine). Stream NDJSON items `{kind:"memory"|"message", ...}`: first emit the recalled memory block (from `DOSClaw-QwenMemory.retrieve`) so the UI can show "what DOSClaw-Qwen remembered", then the agent's final reply, then call `record` to persist the turn.
```python
# Sketch of the core handler (full impl in the file):
# memory = DOSClaw-QwenMemory(customer_id)
# recalled = await memory.retrieve(Msg(name="user", content=text, role="user"))
# yield {"kind":"memory","text":recalled}
# agent = build_agent(customer_id)
# reply = await agent(Msg(name="user", content=text, role="user"))
# yield {"kind":"message","text":reply.content}
# await memory.record([Msg(name="user",content=text,role="user"), reply])
```
(Note: with `long_term_memory_mode="both"`, the agent may also self-record; de-dup by having the HTTP layer own `record` and setting mode to `"agent_control"` only for recall, OR keep `"static_control"` and let the HTTP layer own both record+retrieve. Pick one ownership model during build to avoid double-writes - recommended: `static_control`, HTTP layer owns record+retrieve.)
- [ ] **Step 2: Commit.**

### Task 4.2: `web/index.html` - chat UI

- [ ] **Step 1: Implement** a single-page chat (white + red brand) with: a **customer selector** (Customer A / Customer B), a **"New session"** button (clears the visible thread but NOT the DB memory - so a returning customer demonstrates recall), the chat thread, and a **memory side-panel** that shows the `{kind:"memory"}` block each turn (this visibly proves recall for the track). Render replies with the safe markdown helper (textContent/DOM only, no innerHTML - a security hook rejects innerHTML). Commit.

---

## Phase 5 - Local end-to-end

### Task 5.1: Full local e2e against the live Qwen Cloud + local Postgres

- [ ] **Step 1:** `docker compose up -d db`; apply `db/schema.sql` + `db/seed.sql`; run `python -m dosclaw_qwen.seed_embeddings`. Fill `.env` (DASHSCOPE_API_KEY from the hackathon coupon key). `uvicorn dosclaw_qwen.app:app --port 8092`.
- [ ] **Step 2: Verify the memory demo** over `/api/chat`:
  1. Customer A: "I'm lactose intolerant, what can I drink?" -> knowledge_search -> answer + memory written.
  2. New session, Customer A: "what do you recommend?" -> the memory block shows the lactose/oat-milk profile -> DOSClaw-Qwen proactively recommends oat-milk drinks WITHOUT re-asking (cross-session recall).
  3. Customer B: same question -> NO customer-A memory (isolation).
  4. A refund/complaint -> `human_handoff` -> confirms a ticket.
  5. (Optional) `/api/consolidate` for Customer A -> faded episodes pruned, profile retained.
  Confirm replies are in English for the demo; confirm tool-call activity is visible.

---

## Phase 6 - Deploy on Alibaba Cloud + public repo + deliverables

### Task 6.1: Dockerfile + deploy on Alibaba ECS

- [ ] **Step 1: `Dockerfile`** (python:3.11-slim, install requirements, `uvicorn dosclaw_qwen.app:app --host 0.0.0.0 --port 8092`).
- [ ] **Step 2: Provision an Alibaba ECS** instance (the `aliyun` CLI / RAM user `joy` from memory). On it: `docker compose up -d` (the pgvector DB) + run the app container, env from a server-side `.env` (DASHSCOPE_API_KEY). Open the port / put a reverse proxy. This satisfies "backend running on Alibaba Cloud".
- [ ] **Step 3: Proof of Alibaba** - the deployment proof is a code file in the repo that uses an Alibaba Cloud API: `dosclaw_qwen/model.py` calls DashScope (Alibaba's Qwen Cloud API). Record a short screen capture showing the app responding from the ECS public URL. Document the ECS + deploy steps in `infra/alibaba/README.md`.

### Task 6.2: Public open-source repo + submission deliverables

- [ ] **Step 1: README.md + ARCHITECTURE.md** in `apps/dosclaw_qwen-qwen/` (problem, architecture diagram, the memory design, how to run, the Qwen Cloud + Alibaba usage, license).
- [ ] **Step 2: Extract a PUBLIC repo** (Apache-2.0), e.g. `JOY/DOSClaw-Qwen-Agent`: copy `apps/dosclaw_qwen-qwen/*` (no secrets; `.env.example` only; grep for keys before pushing). License file visible. (Mirror the Bexly-Agent extraction process.)
- [ ] **Step 3: Submission assets** - architecture diagram (PNG), ~3-min demo video (the Task 5.2 memory demo), text description, the proof-of-Alibaba code-file link, testing access (URL + demo login). Identify track = MemoryAgent. Optional: a build-journey blog post for the Blog Post bonus prize.

---

## Self-Review notes
- Spec coverage: framework/runtime (AgentScope, Tasks 2-3), Qwen Cloud model+embeddings (Task 2.1), hybrid memory profile+episodic+recall+forgetting (Tasks 1, 2.2, 2.3), tools knowledge+handoff (Task 3.1), web UI with customer selector + new-session + memory panel (Task 4.2), Alibaba deploy + proof (Task 6.1), public repo + deliverables (Task 6.2). Covered.
- Open items deferred to build (flagged): exact AgentScope 2.0 symbol/signature confirmation (`ReActAgent`/`DashScopeChatModel`/`LongTermMemoryBase` kwargs) against the installed package; the single ownership model for record/retrieve (recommended `static_control`, HTTP layer owns both, to avoid double-writes); the current Qwen chat model id (`qwen3.6-plus` recommended; confirm live) and embedding dim.
- Type consistency: `embed()`, `store.*`, `rank_episodes`, `merge_profile`, `decay_score`, `DOSClaw-QwenMemory.record/retrieve/_write/_recall_block/consolidate` names are used consistently across tasks.
- Prereqs: DASHSCOPE_API_KEY (hackathon $40 coupon) + an Alibaba ECS. Deadline 2026-07-09 (comfortable).
```
