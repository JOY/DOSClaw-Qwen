# Devpost Submission Fields

Use this as the paste-ready checklist for the Global AI Hackathon Series with Qwen Cloud submission.
The current official requirements were rechecked on 2026-06-14 from the Devpost overview and rules pages.

## Project Title

DOSClaw-Qwen

## Tagline

A Qwen Cloud customer-support agent that remembers each customer across sessions.

## Track

MemoryAgent

## Repository URL

```text
https://github.com/JOY/DOSClaw-Qwen
```

## Live Demo URL

```text
http://8.219.211.170/
```

## Testing Instructions

No login is required for the current public demo.

Suggested judge flow:

1. Open `http://8.219.211.170/`.
2. Select `Returning Customer A`.
3. Send `I'm lactose intolerant. What do you recommend?`.
4. Confirm the memory panel recalls Linh's lactose intolerance and oat-milk preference.
5. Click `New session`, switch to `New Customer B`, and send `Do you remember my usual drink?`.
6. Confirm Customer B does not inherit Customer A's memory.
7. Send `I'm JOY, 18 YO`, then start a visible new session and ask `What is my name?`.
8. Confirm the reply recalls JOY and the memory panel shows Customer B's profile.
9. Send `What is your refund policy for coffee beans?`.
10. Confirm the assistant metadata can show `Tool: knowledge_search`.
11. Send `My order was wrong twice. I want a refund and a staff member to review this.`.
12. Confirm the assistant creates a handoff ticket and metadata can show `Tool: human_handoff`.

## Text Description

Paste the story from:

```text
docs/devpost-draft.md
```

It is already formatted with the required Devpost headings:

- Inspiration
- What it does
- How we built it
- Challenges we ran into
- Accomplishments that we're proud of
- What we learned
- What's next for DOSClaw

## MemoryAgent Fit

DOSClaw-Qwen fits the MemoryAgent track because it demonstrates:

- Persistent cross-session memory through AgentScope 2.0 `Mem0Middleware`.
- Native customer and tenant scoping with `user_id=customer_id` and `agent_id=tenant_id`.
- A structured Postgres profile layer for stable facts such as allergies, preferences, age, and complaint state.
- Qdrant-backed episodic vector storage in the deployed runtime.
- Qwen Cloud embeddings for FAQ search and memory storage.
- A visible memory side panel that makes memory recall auditable.
- Active profile updates and consolidation behavior instead of scripted chat state.

## Qwen Cloud And Alibaba Cloud Proof

Use this code file as the official proof link for Alibaba Cloud / Qwen Cloud service usage:

```text
https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py
```

Additional runtime proof:

```text
http://8.219.211.170/api/runtime
https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/deployment-proof.md
https://github.com/JOY/DOSClaw-Qwen/blob/main/scripts/deploy-eci-source.ps1
```

The live runtime is deployed on Alibaba Cloud Elastic Container Instance in `ap-southeast-1` with a Python app container, Postgres/pgvector sidecar, Qdrant sidecar, and nginx public proxy sidecar.

If the form asks for a separate Alibaba runtime proof recording, record a short clip showing:

1. `http://8.219.211.170/api/runtime`.
2. The live app URL.
3. The Alibaba Cloud ECI console for the `dosclaw-qwen` container group, if account access is available.
4. The code proof link above.

## Architecture Diagram

Use one of these links:

```text
https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg
https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.mmd
https://github.com/JOY/DOSClaw-Qwen/blob/main/ARCHITECTURE.md
```

## Demo Video

Upload the demo video to YouTube, Vimeo, or Youku, make it accessible to judges, and paste the URL here:

```text
<PUBLIC_OR_UNLISTED_VIDEO_URL>
```

Local draft video artifact before upload:

```text
docs/proof/dosclaw-qwen-demo-local.mp4
```

## Built With

- AgentScope 2.0
- Mem0Middleware
- Qwen Cloud / DashScope
- FastAPI
- Postgres + pgvector
- Qdrant
- Docker
- Alibaba Cloud Elastic Container Instance

## Significant Update Statement

DOSClaw-Qwen was implemented as a new standalone Python AgentScope 2.0 project during the hackathon period. The older Next.js scripted demo was preserved only on the `legacy-nextjs-demo` branch and was replaced by a real AgentScope + Mem0Middleware + Qwen Cloud memory runtime on `main`.

## Optional Blog Or Social Post

No blog/social URL is required unless submitting for the optional blog post prize.
