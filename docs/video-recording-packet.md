# DOSClaw-Qwen Video Recording Packet

Target length: 2:45 to 3:00. Upload the final video to YouTube, Vimeo, or Youku and make it accessible to judges without login.

## Recording Setup

- Browser tab: deployed DOSClaw-Qwen URL. Local rehearsal URL: `http://localhost:8092`.
- Repo tab: `https://github.com/JOY/DOSClaw-Qwen`.
- Code proof tab: `dosclaw_qwen/model.py`.
- Optional terminal tab: smoke script output.
- Optional cloud tab: Alibaba Cloud runtime console or ECS host proof.

## Timeline

| Time | Screen | Narration |
| --- | --- | --- |
| 0:00-0:15 | Web UI | "DOSClaw-Qwen is a Qwen Cloud MemoryAgent for SME customer support. It remembers customers across sessions without mixing them together." |
| 0:15-0:35 | Architecture | "The app uses AgentScope 2.0, Qwen Cloud chat and embeddings, Mem0Middleware with Qdrant, Postgres profile memory, FAQ search, human handoff, consent controls, and visible memory controls." |
| 0:35-1:10 | Returning Customer A | "First, a returning customer asks for a recommendation. The memory panel shows lactose intolerance and oat milk preference before the answer." |
| 1:10-1:35 | Customer B | "Now a different customer starts a new session. Customer A's memories do not leak into Customer B." |
| 1:35-2:00 | Knowledge answer | "Policy questions are grounded through tenant knowledge search rather than guessed, and the knowledge base is visible in the UI." |
| 2:00-2:25 | Handoff + operations | "Refund or complaint cases create a real handoff ticket before the assistant confirms escalation, and staff can review it in the dashboard." |
| 2:25-2:45 | Code proof | "Qwen Cloud is called from `dosclaw_qwen/model.py`; the backend is containerized for Alibaba Cloud." |
| 2:45-3:00 | Closing | "The result is a focused MemoryAgent: persistent memory, scoped retrieval, timely context, and auditable escalation." |

## Click Path

1. Select `Returning Customer A`.
2. Send `I'm lactose intolerant. What do you recommend?`
3. Click `New session`.
4. Switch to `New Customer B`.
5. Send `Do you remember my usual drink?`
6. Send `What is your return policy for coffee beans?`
7. Pause and resume memory consent in the Profile & consent panel.
8. Switch the tenant to `Deckhouse Skate Shop` and show the FAQ rows change.
9. Switch back to `Bloom Cafe`.
10. Send `My order was wrong twice. I want a refund and a staff member to review this.`
11. Show the Staff handoffs panel.
12. Show `dosclaw_qwen/model.py`.
13. Show `ARCHITECTURE.md` or `docs/architecture.mmd`.

## Required Lines To Say

- "Qwen Cloud powers both chat and embeddings."
- "Memories are scoped with `user_id=customer_id` and `agent_id=tenant_id`."
- "The memory panel exposes recalled facts so judges can see the system is not just prompt theater."
- "The Mem0 controls expose list, get, search, add, update, delete, delete-all, and history for scoped customer memory."
- "Customers can pause automatic memory writes and still review or forget stored memory."
- "The tenant switcher proves shop knowledge and customer context stay isolated."
- "The staff handoff dashboard turns the escalation into an auditable support workflow."
- "The assistant metadata exposes the active Qwen model, memory backend, and tool calls."
- "The handoff flow is honest: a ticket is created before escalation is confirmed."

## Post-Recording Checklist

- [ ] Optional local MP4 render is created with `scripts/render-demo-video.ps1` after collecting screenshots in `docs/proof/video-frames/`.
- [ ] Video URL is public or unlisted-publicly-viewable on YouTube, Vimeo, or Youku.
- [ ] Video URL is added to `docs/devpost-submission-fields.md`.
- [ ] Video URL is added to `docs/judging-packet.md`.
- [ ] Live URL and login are added to `docs/devpost-submission-fields.md`.
- [ ] `scripts/smoke-scenarios.ps1` evidence is captured for the live URL.
- [ ] `scripts/package-submission.ps1` is rerun.
