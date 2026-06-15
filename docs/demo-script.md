# DOSClaw-Qwen Demo Script

Target length: 2:30 to 3:00. Demo language: English.

## Scene 1: Returning Customer Memory

Screen: web UI with customer selector set to `Returning Customer A`.

Customer message:

```text
I'm lactose intolerant. What do you recommend?
```

Expected flow:

1. The UI emits a `memory` block before the assistant answer.
2. The profile block recalls that this customer is Linh, is lactose intolerant, and prefers oat milk lattes.
3. AgentScope routes the reply through Qwen Cloud.
4. The assistant metadata shows the Qwen model, Mem0/Qdrant backend, and any tool activity.
5. The Profile & consent panel shows the durable profile facts and whether automatic memory writes are active.
6. The Memory controls panel can list, get, search, add, update, delete all, and show history for scoped Mem0 memories.
7. The assistant recommends dairy-free options without asking the customer to repeat the preference.

Success line:

```text
DOSClaw-Qwen remembers the customer across sessions and shows the recalled facts before answering.
```

## Scene 2: Multi-Customer Isolation

Screen: switch selector to `New Customer B`, then start a new session.

Customer message:

```text
Do you remember my usual drink?
```

Expected flow:

1. The memory panel does not leak Linh's lactose intolerance or oat-latte preference.
2. The assistant avoids pretending it knows Customer B's preference.
3. Any new preference learned for Customer B is scoped to `user_id=cust_b`.

Success line:

```text
Customer memory is isolated by customer and tenant, not by a shared global chat history.
```

## Scene 3: Knowledge-Grounded Answer

Screen: keep either customer selected.

Customer message:

```text
What is your return policy for coffee beans?
```

Expected flow:

1. The agent can use `knowledge_search`.
2. The answer is grounded in Bloom Cafe FAQ rows, not invented policy text.
3. The assistant metadata shows `Tool: knowledge_search`.
4. The Knowledge base panel shows the same tenant FAQ rows that ground the answer.
5. The answer remains concise and customer-support shaped.

Success line:

```text
DOSClaw-Qwen combines persistent customer memory with tenant-specific knowledge lookup.
```

## Scene 4: Tenant Isolation

Screen: switch the shop selector from `Bloom Cafe` to `Deckhouse Skate Shop`.

Expected flow:

1. The customer selector changes to skater customers.
2. The Knowledge base panel changes to skate-shop FAQ rows.
3. The analytics strip updates for the selected tenant.
4. Bloom Cafe customer memory does not appear in the skate-shop context.

Success line:

```text
Tenant isolation is visible in the UI, not just hidden in backend IDs.
```

## Scene 5: Honest Human Handoff

Customer message:

```text
My order was wrong twice. I want a refund and a staff member to review this.
```

Expected flow:

1. The agent calls `human_handoff`.
2. A row is created in `handoffs`.
3. The assistant metadata shows `Tool: human_handoff`.
4. The Staff handoffs panel shows the ticket and lets staff mark it `reviewing` or `resolved`.
5. The assistant confirms escalation only after the tool succeeds.

Success line:

```text
The handoff is honest: the assistant does not claim staff escalation until the tool records it.
```

## Closing

DOSClaw-Qwen is a MemoryAgent-track customer-support system: AgentScope 2.0, Qwen Cloud chat and embeddings, mem0-backed episodic memory with agent-controlled `search_memory`/`add_memory`, a structured profile layer, tenant-scoped knowledge search, consent-aware memory controls, support analytics, and an auditable staff handoff path.
