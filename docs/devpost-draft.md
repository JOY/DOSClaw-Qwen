## Inspiration

Small businesses often need customer-support agents that remember the right things without becoming creepy, leaky, or scripted. A cafe should not have to ask a returning customer about the same allergy every time, but it also cannot let one customer's profile bleed into another customer's support session.

DOSClaw-Qwen was built for that narrow but very real problem: an SME support agent that remembers per-customer preferences, uses tenant knowledge, and escalates honestly when a human should review the case.

## What it does

DOSClaw-Qwen is a multilingual SME customer-support agent for the MemoryAgent track. The demo runs in English so judges can follow the memory behavior clearly.

The agent can:

- Recall stable customer facts across visible new sessions.
- Keep Customer A and Customer B memory isolated.
- Store and update structured profile facts such as name, age, allergies, preferences, last order, and complaint state.
- Use Qwen Cloud embeddings and tenant FAQ rows for knowledge-grounded answers.
- Create a human handoff ticket before claiming escalation.
- Show the recalled memory block, active Qwen model, embedding model, memory backend, memory scope, and tool calls directly in the web UI.

The live demo is deployed at:

```text
http://8.219.211.170/
```

## How we built it

The project is a standalone Python AgentScope 2.0 app, not a scripted chat demo.

Core runtime:

- FastAPI serves the chat API and static web UI.
- AgentScope 2.0 runs the support agent and tool-calling loop.
- Qwen Cloud / DashScope provides `qwen3.6-plus` for chat reasoning.
- Qwen Cloud `text-embedding-v4` provides embeddings for FAQ search and memory storage.
- AgentScope `Mem0Middleware` stores episodic long-term memory.
- Qdrant stores mem0 episodic vectors in the deployed runtime.
- Postgres + pgvector stores tenants, customers, structured profiles, knowledge rows, and handoff tickets.
- The web UI streams NDJSON events so judges see memory recall, model metadata, tool metadata, and the final answer.
- The live runtime runs on Alibaba Cloud Elastic Container Instance with app, Postgres/pgvector, Qdrant, and nginx sidecars.

The memory scope maps naturally to multi-tenant support:

```text
mem0 user_id = customer_id
mem0 agent_id = tenant_id
```

Proof links:

- Qwen Cloud adapter: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py
- FastAPI demo surface: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/app.py
- Architecture SVG: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg
- Deployment proof notes: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/deployment-proof.md

## Challenges we ran into

The hardest part was making the demo use real memory while still staying judge-friendly.

Key challenges:

- AgentScope 2.0 APIs are still moving, so we verified the installed API by introspection before wiring models, tools, and middleware.
- Mem0 needed to be routed through the same DashScope/Qwen configuration instead of falling back to OpenAI.
- The memory UI had to expose enough evidence for judges without dumping raw internals into every answer.
- Customer isolation had to work across both structured profile memory and episodic mem0 memory.
- Alibaba Cloud ECI updates restart the container group, so every deployment needs a smoke run that reseeds and verifies the live demo behavior.
- The first UI stream implementation could leave the composer disabled while the HTTP stream stayed open; we fixed the UI to unlock when the final assistant message arrives.
- The demo needed a clean submission packet: architecture, smoke evidence, paste-ready Devpost fields, and a local video artifact.

## Accomplishments that we're proud of

- The deployed app uses real Qwen Cloud chat and embeddings.
- Memory is scoped by customer and tenant rather than a shared global chat history.
- The web UI makes memory visible: judges can see what was recalled before each answer.
- Tool metadata is visible under assistant replies, including `knowledge_search` and `human_handoff`.
- Refund escalation creates an auditable ticket path instead of pretending a human was notified.
- The project includes live smoke scenarios that verify returning memory, customer isolation, profile learning, recall, knowledge grounding, and handoff behavior.
- The public repo includes a complete evidence package, architecture diagram, video recording packet, and paste-ready Devpost submission fields.

## What we learned

Memory agents are only convincing when the retrieval boundary is visible. If judges cannot see what the agent remembered and why, the demo looks like prompt theater.

We also learned that customer support memory needs two layers:

- Episodic memory for flexible past interactions.
- Structured profile memory for durable facts that need deterministic display and conflict handling.

AgentScope and Qwen Cloud made the agent path straightforward once the API surface was verified, but deployment taught us to treat live cloud state as part of the product. Smoke tests, runtime metadata, and repeatable proof packaging mattered as much as the app code.

## What's next for DOSClaw

The next step is turning DOSClaw-Qwen from a focused hackathon demo into a deployable support memory service:

- Add a staff dashboard for handoff tickets and profile review.
- Add explicit customer consent controls for remembering, editing, and forgetting profile facts.
- Add multi-tenant admin setup for different SME shops.
- Add richer memory consolidation so outdated preferences decay or require confirmation.
- Add analytics for recall quality, handoff rate, and customer satisfaction.
- Package the AgentScope + Mem0 + Qwen Cloud memory pattern as a reusable example for other builders.
