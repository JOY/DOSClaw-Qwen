# Building Huyen: A Qwen Cloud Support Autopilot for Vietnamese SMEs

Vietnamese small businesses often run customer support through chat channels, spreadsheets, and informal staff handoffs. That works while the business is tiny, but it breaks in three predictable ways:

- repeat customers have to explain the same context again;
- staff answer policy questions from memory and sometimes guess;
- escalation is messy, and customers may be told that a human was notified before anyone actually owns the case.

Huyen is a focused attempt to turn that messy support flow into a production-shaped AI agent. It is spun out from DOSClaw as a standalone Qwen Cloud hackathon product: one agent, one business workflow, and a small set of verifiable behaviors.

## What Huyen Does

Huyen handles three support workflows:

1. **Returning customer memory**: a customer asks about same-day delivery, and Huyen recalls the customer's saved preference before answering.
2. **Knowledge-grounded policy answer**: a customer asks about warranty and returns, and Huyen searches business policy evidence before drafting a reply.
3. **Honest human handoff**: a customer reports a repeated product failure and asks for staff or a refund, and Huyen calls the handoff tool before confirming escalation.

The important part is not that Huyen can chat. The important part is that every answer is tied to a control surface: memory, knowledge, or handoff.

## Why Qwen Cloud

Qwen Cloud gives Huyen a production-friendly model path through the OpenAI-compatible Chat Completions endpoint. The public demo includes a live adapter in `src/lib/qwen.ts`. When `QWEN_CLOUD_API_KEY` or `DASHSCOPE_API_KEY` is configured, `/api/demo` sends the selected scenario and tool evidence to Qwen Cloud. When no secret is available, the repo stays runnable through a clearly labeled synthetic fallback.

That fallback matters for open source judging: the repository can be cloned, built, and tested without exposing private keys, while the same code path is ready to use Qwen Cloud in the deployed environment.

## Architecture

Huyen keeps the product boundary intentionally small:

- **OpenClaw** runs the agent runtime and chat channels.
- **DOSClaw** provides the control plane for memory, knowledge, and handoff tools.
- **Qwen Cloud** is the primary reasoning path.
- **The public Huyen app** provides the product surface, demo API, deployment runbook, smoke tests, and submission proof packet.

The architecture diagram lives in `docs/architecture.mmd`, and the runtime contract is documented in `docs/huyen-agent-config.md`.

## Engineering Choices

### 1. Live Qwen adapter plus public fallback

The public API does not pretend to call Qwen Cloud when no key is configured. The response includes `answerSource`, `liveQwen`, and `qwenConfigured` so judges can see whether the response came from Qwen Cloud or the fallback path.

### 2. Scenario smoke tests as proof

The `scripts/smoke-scenarios.ps1` script checks:

- `/api/health`;
- all three demo scenarios;
- the `qwen-cloud/*` model reference;
- MCP tool evidence;
- `answerSource`.

It writes JSON evidence under `docs/proof/`, which can be included in the final Devpost package.

### 3. Deployment proof is explicit

The hackathon requires Alibaba Cloud backend proof. Huyen includes:

- an Alibaba Cloud deployment runbook;
- a RAM policy template;
- a preflight script that checks ACR, Function Compute, and ECI permissions;
- an issue tracking the current permission blocker.

This is intentionally boring infrastructure work, but boring is good when the goal is a production-ready agent rather than a toy demo.

## What I Learned

The most useful design constraint was to make Huyen narrow. Instead of building a generic agent platform, the submission focuses on a business workflow where agents often fail in real deployments: remembering the right context, grounding policy answers, and escalating honestly.

Qwen Cloud fits well here because the model call is not isolated from the rest of the system. It sits inside a workflow with tool evidence and checks around it.

## Next Steps

The remaining gate is Alibaba Cloud runtime permission. Once the RAM policy is attached, the deploy path is:

1. run `scripts/preflight-alibaba.ps1`;
2. push the Docker image to Alibaba Cloud Container Registry;
3. deploy on Function Compute or Elastic Container Instance;
4. run `scripts/smoke-scenarios.ps1` against the public URL;
5. record the three-minute demo using `docs/video-recording-packet.md`;
6. package the evidence with `scripts/package-submission.ps1`.

Huyen is small by design. It is a support autopilot that remembers, checks, and escalates: the three behaviors Vietnamese SMEs need before they can trust an AI agent with real customers.
