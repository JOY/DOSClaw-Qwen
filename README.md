# DOSClaw-Qwen - an SME support agent that actually remembers its customers

DOSClaw-Qwen is a customer-support agent for small businesses, built for the **Global AI
Hackathon Series with Qwen Cloud** (**MemoryAgent track**). Its differentiator is a real
**per-customer persistent memory** engine: DOSClaw-Qwen remembers each customer across sessions, recalls
the right facts in a limited context window, and forgets stale ones - so returning customers are
never asked the same thing twice.

Built on **AgentScope 2.0** (Alibaba's open-source agent framework) and **Qwen Cloud / DashScope**
(`qwen3.6-plus` for reasoning, `text-embedding-v4` for semantic memory), deployed on **Alibaba Cloud**.

## Why it fits MemoryAgent

The track rewards autonomous experience accumulation, efficient storage/retrieval, timely
forgetting, and recalling critical memories within a limited context window. DOSClaw-Qwen implements all
four with a hybrid memory:

- **Profile (structured, durable):** stable facts per customer (name, preferences, allergies, last
  order). Updated by an LLM extraction step after each turn; conflicting facts are overwritten.
- **Episodic (semantic, decaying):** concise summaries of past interactions, embedded into
  **pgvector** with an importance score and timestamp.
- **Recall in a limited context:** before replying, DOSClaw-Qwen assembles a compact block = full profile
  + top-K episodic memories ranked by a blend of **semantic similarity and recency** - only that
  block enters the prompt, not the whole history.
- **Forgetting / consolidation:** episodic memories carry a recency x importance decay; faded ones
  are pruned while durable facts persist in the profile.

## Architecture

```
Web chat UI (customer selector + new-session + "memory recalled" panel)
        |  HTTP / SSE
FastAPI  --  AgentScope Agent (Qwen qwen3.6-plus via DashScope)
        |        |  tools: knowledge_search (FAQ RAG), human_handoff, search_memory
        |   MemoryService  --  recall / record / consolidate
        |        |
   Postgres + pgvector  (profile, episodic_memory, knowledge, handoffs)   [on Alibaba Cloud]
        |
   DashScope: qwen3.6-plus (chat) + text-embedding-v4 (embeddings)        [Qwen Cloud]
```

Everything runs on Alibaba Cloud (ECS + Dockerized Postgres, or RDS); Qwen Cloud provides the model
and embeddings. The proof-of-Alibaba code file is [`dosclaw_qwen/model.py`](dosclaw_qwen/model.py).

## Status

Under active construction. Project scaffold, DB schema, and the verified AgentScope 2.0.1 API
reference are in place. See **[HANDOFF.md](HANDOFF.md)** for the build brief and
**[docs/implementation-plan.md](docs/implementation-plan.md)** for the task-by-task plan.

## Run locally

Prerequisites: Python 3.11+ (3.14 works), Docker, and a Qwen Cloud `DASHSCOPE_API_KEY`.

```bash
cp .env.example .env          # fill in DASHSCOPE_API_KEY
docker compose up -d db       # Postgres + pgvector
python -m venv .venv && . .venv/Scripts/activate   # (Windows: .venv\Scripts\activate)
pip install -r requirements.txt
# apply schema + seed, then run the seed-embeddings script and the app (see docs/implementation-plan.md)
uvicorn dosclaw_qwen.app:app --port 8092
```

## Docs

- [HANDOFF.md](HANDOFF.md) - build brief (start here if you are implementing)
- [docs/AGENTSCOPE_API.md](docs/AGENTSCOPE_API.md) - verified AgentScope 2.0.1 API
- [docs/implementation-plan.md](docs/implementation-plan.md) - task-by-task TDD plan
- [docs/spec-design.md](docs/spec-design.md) - design rationale
- [docs/hackathon-reference.md](docs/hackathon-reference.md) - hackathon rules and deliverables
- [docs/legacy/](docs/legacy/) - assets from a prior, abandoned Next.js attempt (reference only)

## License

MIT - see [LICENSE](LICENSE).
