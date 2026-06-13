# Global AI Hackathon Series with Qwen Cloud - Reference

> Captured 2026-06-09 from the official Devpost pages (rendered via browser; the pages are
> JS-only and blank to plain fetch). Source of truth for our DOSClaw-Qwen / MemoryAgent submission.
> Links: https://qwencloud-hackathon.devpost.com/ · /rules · /resources

## Dates (Pacific Time)
- Submission Period: **May 26, 2026 (8:00am PT) - Jul 9, 2026 (2:00pm PT)**. (Devpost header shows "Jul 10, 2026 4:00am GMT+7".)
- Judging: Jul 10 - Jul 31, 2026. Winners announced ~Aug 7, 2026.

## Sponsor / Admin
- Sponsor: **Alibaba Cloud** (Singapore). Administrator: Devpost.

## Hard requirements
- **Must build using Qwen models on Qwen Cloud** (DashScope). API base URL (OpenAI-compatible):
  `https://dashscope-intl.aliyuncs.com/compatible-mode/v1`.
- **Must be deployed on Alibaba Cloud infrastructure.** Proof of deployment = **a link to a code
  file in the repo that demonstrates use of Alibaba Cloud services and APIs** (note: proof is a
  CODE FILE, not just a recording; DashScope/Qwen Cloud is an Alibaba API, so the file calling it
  counts, plus running the backend on Alibaba).
- **New or significantly updated**: project must be newly created during the Submission Period,
  or if pre-existing, significantly updated after the start (and explain the update).
- **No direct copying** of existing open-source projects; open-source building blocks (frameworks
  like AgentScope) are allowed only if you "create software that enhances and builds upon" them.
- **English** required (or English translation of video/description/testing instructions).
- Teams 1-5; an individual may join multiple teams.

## Submission requirements (deliverables)
1. Public **code repo** with all source + assets + instructions; **open-source license file**
   visible in the repo About section.
2. **Text description** of features/functionality.
3. **Proof of Alibaba Cloud deployment** (link to a code file using Alibaba Cloud services/APIs).
4. **Architecture diagram** (how Qwen Cloud connects to backend, DB, frontend).
5. **Demo video** < 3 minutes, public on YouTube / Vimeo / Youku, link on the submission form.
6. **Identify the track.**
7. **Testing access**: working demo / link / test build, free for judges until judging ends;
   include login credentials if private.
8. Optional: a **published blog/social post** about the build journey (link in submission) for
   the Blog Post bonus prize.

## The 5 tracks
1. **MemoryAgent** (OUR TRACK): persistent memory; autonomously accumulate experience, remember
   user preferences, cross-session multi-turn; focus on efficient storage/retrieval, timely
   forgetting of outdated info, recalling critical memories in limited context windows.
   Official idea list includes: *"a customer support agent that recalls full conversation history
   and user preferences without re-asking"* (= exactly our DOSClaw-Qwen).
2. **AI Showrunner**: video generation (Wan / HappyHorse), full short-drama pipeline; highest
   token allowance.
3. **Agent Society**: multi-agent collaboration (task division, dialogue, negotiation); measurable
   efficiency gain over single-agent baselines.
4. **Autopilot Agent**: automate real-world business workflows end-to-end (e.g. inquiry email ->
   quote; alert -> remediation); ambiguous inputs, external tools, human-in-the-loop checkpoints;
   production-readiness over toy demos. (DOSClaw-Qwen also plausibly fits here; we chose MemoryAgent.)
5. **EdgeAgent**: Qwen-powered physical devices (robots/IoT); edge-cloud orchestration, offline
   degradation.

## Judging criteria
- Stage One: pass/fail viability (fits theme + reasonably uses the required APIs/SDKs).
- Stage Two (weighted):
  - **Innovation & AI Creativity (30%)** - sophisticated use of Qwen Cloud APIs (custom skills,
    MCP integrations); algorithm/engineering innovation, custom components, perf optimization.
  - **Technical Depth & Engineering (30%)** - architecture quality (modularity, scalability,
    error handling); clean code, non-trivial logic; tech-stack sophistication.
  - **Problem Value & Impact (25%)** - real-world relevance; productization / open-source potential.
  - **Presentation & Documentation (15%)** - demo clarity (key logic visualized); architecture docs.

## Prizes
- **Each of the 5 tracks**: **$7,000 cash + $3,000 cloud credits** + blog feature + swag (1 winner/track).
- Top 10 Honorable Mention: $500 cash + $500 credits.
- Top 10 Blog Post Award: $500 cash + $500 credits.
- A project can win at most 1 grand prize + 1 blog prize.

## Resources / links
- Quick start: register on Devpost; sign up Qwen Cloud (free trial + hackathon credits via coupon
  form); join Discord.
- **Free credits / benefits**: https://home.qwencloud.com/benefits
- **$40 voucher coupon form**: https://www.qwencloud.com/challenge/hackathon/voucher-application
  (responsible for fees beyond $40).
- **Discord**: https://discord.gg/cDEHSV4Qqj
- Docs: intro https://bit.ly/intro-qwencloud · first API call https://bit.ly/qwencloud-first-api ·
  model selection https://bit.ly/qwencloud-modelselection · pricing https://bit.ly/qwencloud-pricing ·
  get API key https://bit.ly/qwencloud-getapi · support https://bit.ly/qwencloud-support
- Project gallery: /project-gallery · Updates: /updates · Forum: /forum_topics

## Our submission (decided)
- Track: **MemoryAgent**. Project: **DOSClaw-Qwen** - multilingual SME customer-support agent with per-customer
  persistent memory. Runtime: **AgentScope** (QwenPaw as reference only, NOT forked). Model:
  Qwen Cloud (DashScope). Deploy: Alibaba ECS + Postgres/pgvector on Alibaba. Design spec:
  `docs/superpowers/specs/2026-06-09-dosclaw_qwen-qwen-memoryagent-design.md`.
