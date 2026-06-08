# Huyen Social Post Draft

## Short Post

I am building Huyen for the Qwen Cloud hackathon: a Vietnamese SME support autopilot spun out from DOSClaw.

Huyen focuses on three production behaviors that generic chatbots usually miss:

- remembering returning customers;
- answering policy questions only after knowledge lookup;
- escalating to a human honestly, after the handoff tool succeeds.

The public repo includes a live Qwen Cloud adapter, Docker build, smoke tests for all scenarios, architecture docs, and a submission evidence packet.

Repo: https://github.com/JOY/huyen-qwen-cloud

## Longer Post

For the Qwen Cloud hackathon, I am spinning Huyen out of DOSClaw into a standalone product: a support autopilot for Vietnamese small businesses.

The goal is not a generic chatbot demo. Huyen is built around three support workflows:

1. A returning customer asks about same-day delivery, and Huyen recalls saved customer memory.
2. A customer asks about warranty and returns, and Huyen searches knowledge evidence before answering.
3. A customer reports a repeated product failure, and Huyen calls a human handoff tool before confirming escalation.

Qwen Cloud is the primary reasoning path through an OpenAI-compatible adapter. OpenClaw handles the agent runtime, and DOSClaw supplies memory, knowledge, and handoff tools.

The repo is public, licensed, Dockerized, and includes smoke proof automation for all three scenarios.

Repo: https://github.com/JOY/huyen-qwen-cloud

## Hashtags

`#QwenCloud` `#AlibabaCloud` `#AIHackathon` `#AIAgents` `#VietnameseSME` `#OpenSource`
