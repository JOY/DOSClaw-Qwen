# Huyen Qwen Cloud Agent Config

## Submission Positioning

Huyen is a Qwen Cloud-powered Vietnamese SME support autopilot built on DOSClaw/OpenClaw.

- OpenClaw is the runtime and channel orchestrator.
- DOSClaw provisions the agent, stores per-customer memory, serves knowledge and handoff MCP tools, and manages channels.
- Qwen Cloud is the primary reasoning and response model for the hackathon demo.

Primary track: Track 4, Autopilot Agent.

Secondary fit: Track 1, MemoryAgent, because the demo uses persistent per-customer memory across sessions.

## Required Gateway Environment

```bash
QWEN_CLOUD_API_KEY=<DashScope or Qwen Cloud API key>
QWEN_CLOUD_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1
QWEN_CLOUD_MODEL=qwen3.7-plus
```

`DASHSCOPE_API_KEY` can be used as the fallback key source when `QWEN_CLOUD_API_KEY` is unset.

## Agent Config Payload

```json
{
  "template": "customer-service",
  "config": {
    "qwen_cloud_submission": true,
    "qwen_cloud_model": "qwen3.7-plus",
    "default_model": "qwen-cloud/qwen3.7-plus",
    "permission_mode": "ask_permission",
    "handoff": {
      "enabled": true,
      "channel": "telegram",
      "target": "@support_operator"
    },
    "custom_identity": "# IDENTITY.md\n\n- **Name:** Huyen\n- **Role:** Vietnamese SME Support Autopilot\n- **Vibe:** warm, precise, honest\n\nWhen users ask your name, respond with \"Huyen\".",
    "custom_soul": "# SOUL.md\n\nYou are Huyen, a Vietnamese SME support autopilot. You help customers with product questions, order preferences, warranty and policy questions, and handoff to a real staff member when the case is risky or unresolved.\n\nAnswer in Vietnamese by default. Be concise, warm, and practical. Never invent product, pricing, warranty, delivery, refund, or customer-specific facts. Use search_knowledge before answering business facts, use search_memory for returning customers, and use handoff_to_human for complaints, refund requests, legal/safety issues, or when the customer explicitly asks for staff."
  }
}
```

## Demo Data

Knowledge base rows:

| Topic | Answer |
| --- | --- |
| Warranty | Product warranty is 12 months for manufacturing defects. |
| Delivery | Ho Chi Minh City delivery is usually same-day before 5pm. Other provinces take 2-4 days. |
| Return policy | Returns are accepted within 7 days when the product is unused and packaging is intact. |

Memory facts:

| Customer | Fact |
| --- | --- |
| `zalo:user-001` | Customer name is Minh and prefers same-day delivery in Ho Chi Minh City. |
| `zalo:user-002` | Customer usually orders the compact black model. |

Handoff case:

```text
Customer says: "May bi loi lan thu hai roi, cho anh gap nhan vien hoac hoan tien."
Expected behavior: Huyen calls handoff_to_human with a short case summary, then only confirms after the tool returns success.
```
