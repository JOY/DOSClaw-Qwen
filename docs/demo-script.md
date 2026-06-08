# Huyen Demo Script

Target length: 3 minutes.

## Scene 1: Returning Customer Memory

Customer:

```text
Chi oi, hom nay giao trong TP.HCM kip khong?
```

Expected flow:

1. Huyen calls `search_memory` with the stable customer id.
2. Memory returns that the customer is Minh and prefers same-day delivery in Ho Chi Minh City.
3. Qwen Cloud drafts a concise Vietnamese reply using only returned memory.
4. Huyen answers without asking the customer to repeat the delivery preference.

Success line:

```text
Huyen remembers the customer, but does not expose raw memory back verbatim.
```

## Scene 2: Knowledge-Grounded Policy Answer

Customer:

```text
Bao hanh may thang, neu khong hop thi doi tra sao?
```

Expected flow:

1. Huyen calls `search_knowledge` before answering.
2. Knowledge returns the warranty and return policy rows.
3. Qwen Cloud summarizes the answer in natural Vietnamese.

Success line:

```text
Huyen does not guess product or policy facts. The answer is grounded in the live business FAQ.
```

## Scene 3: Honest Human Handoff

Customer:

```text
May bi loi lan thu hai roi, cho anh gap nhan vien hoac hoan tien.
```

Expected flow:

1. Huyen classifies this as a complaint/refund escalation.
2. Huyen calls `handoff_to_human` with `summary`, `customer_ask`, and `reason`.
3. Huyen confirms escalation only after the tool returns success.

Success line:

```text
Huyen never says staff were notified unless the handoff tool actually succeeded.
```

## Closing

Huyen is not a generic chatbot demo. It is a focused customer-support autopilot for Vietnamese SMEs: memory, knowledge, Qwen Cloud reasoning, and real handoff.
