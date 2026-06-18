# Building DOSClaw-Qwen: the technical journey behind a real Qwen Cloud MemoryAgent

Publication draft for the optional Blog Post Prize.

Publish this on Substack, LinkedIn, Dev.to, Medium, Hashnode, or another public blog/social platform, then paste the published URL into the Devpost field.

## English

# Building DOSClaw-Qwen: the technical journey behind a real Qwen Cloud MemoryAgent

Most hackathon chat demos look convincing for one conversation. The harder question is what happens after the tab is refreshed, the customer comes back tomorrow, or a different customer uses the same shop account.

That is the problem I wanted DOSClaw-Qwen to answer. It is a multilingual customer-support agent for small and medium businesses, built for the Global AI Hackathon Series with Qwen Cloud. The goal was not only to call a model. The goal was to build a small but real memory system: one that can remember a customer across sessions, keep tenant and customer boundaries intact, ground answers in shop knowledge, and show judges exactly what memory was recalled before an answer is generated.

The current live demo runs at:

http://8.219.211.170/

The public repository is:

https://github.com/JOY/DOSClaw-Qwen

## Why this needed to be more than a chatbot

The product scenario is intentionally ordinary: a cafe, clinic, repair shop, or local store that talks to repeat customers every day.

A useful support agent should remember facts such as:

- the customer prefers oat milk
- the customer is lactose intolerant
- the customer bought a specific product last time
- a complaint is still waiting for human follow-up

But memory is also dangerous if it is global or invisible. If Customer A says "I am allergic to dairy," Customer B must not inherit that fact. If the agent says "I remember you," the UI should be able to show what it remembered and where that memory lives. That became the design constraint:

> DOSClaw-Qwen should behave like a support agent with memory, but the memory must be scoped, visible, auditable, and testable.

## The system architecture

The deployed app is a standalone Python application, not a mock front end around a hidden prompt. The main path is:

```text
Browser UI
  -> FastAPI /api/chat
  -> ChatService
       1. Load tenant + customer profile from Postgres
       2. Check memory consent
       3. Recall episodic memory through Mem0Middleware
       4. Build a compact support context
       5. Call an AgentScope 2.0 agent backed by Qwen Cloud
       6. Let tools search knowledge or create a human handoff
       7. Persist new memory/profile updates after the reply
  -> Stream answer + memory/model/tool metadata back to the UI
```

The runtime stack is:

- **Agent runtime:** AgentScope 2.0
- **Chat model:** Qwen Cloud / DashScope `qwen3.6-plus`
- **Embedding model:** Qwen Cloud / DashScope `text-embedding-v4` with 1024 dimensions
- **Episodic memory:** Mem0Middleware
- **Vector store for mem0:** Qdrant
- **Structured state:** Postgres for tenants, customers, profiles, FAQ rows, analytics, and handoff tickets
- **API and UI:** FastAPI plus a static judge-facing web UI
- **Deployment:** Alibaba Cloud Elastic Container Instance with app, Postgres, Qdrant, and nginx sidecars

The architecture diagram is in the repo:

https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg

## The memory design: two layers, one boundary

The most important implementation decision was to avoid treating "memory" as one vague bucket. DOSClaw-Qwen uses two layers.

### 1. Structured profile memory

Structured profile memory stores durable facts that the business should be able to display and audit, for example:

```json
{
  "name": "Linh",
  "prefers": "oat milk lattes",
  "lactose_intolerant": true,
  "last_order": "oat latte + almond croissant"
}
```

This is useful for facts that should be stable in the UI and easy to edit or forget.

### 2. Episodic memory through Mem0Middleware

Episodic memory stores conversational memories and semantic recall. This is where Qwen Cloud embeddings matter: memories and FAQ rows can be retrieved by meaning, not only by exact keywords.

The multi-user boundary is simple and deliberate:

```text
mem0 user_id  = customer_id
mem0 agent_id = tenant_id
```

That means the same backend can support multiple shops and multiple customers without mixing recall. A judge can teach "New Customer B" a name and age, start a new visible session, and ask what the agent remembers. Then they can switch back to "Returning Customer A" and verify that Customer A's seeded cafe preferences remain separate.

## How Qwen Cloud is used

Qwen Cloud is used in two places:

1. **Reasoning and response generation** through the DashScope chat model.
2. **Embeddings** for semantic memory and knowledge search.

The proof code for Qwen Cloud model wiring is here:

https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

One important constraint was that Mem0Middleware must not silently fall back to an OpenAI path. The memory engine had to be powered through the same DashScope/Qwen stack as the agent. That made the integration more work, but it also made the demo honest: the model, embeddings, memory recall, and visible runtime metadata all point to the same Qwen Cloud-based system.

The live runtime endpoint exposes the proof:

```json
{
  "chat_model": "qwen3.6-plus",
  "embedding_model": "text-embedding-v4",
  "embedding_dimensions": 1024,
  "agent_runtime": "AgentScope 2.0",
  "memory_engine": "Mem0Middleware",
  "vector_store": "Qdrant server 127.0.0.1:6333",
  "memory_scope": "tenant_id + customer_id"
}
```

## Why the UI exposes internals

For a memory-agent demo, a polished answer is not enough. A judge should be able to tell whether the system actually recalled something or just produced a plausible sentence.

That is why the UI shows:

- the current tenant/shop
- the selected customer persona
- the recalled memory block
- the structured customer profile
- the active Qwen model and embedding model
- the memory backend
- knowledge base search results
- human handoff tickets
- memory controls such as search, add, update, history, forget, and forget all

This is not just a design choice. It is a debugging and trust choice. If recall fails, the failure is visible. If the wrong customer is selected, the scope is visible. If the agent uses knowledge search or handoff tools, the tool evidence is visible.

## The build process

The implementation order was intentionally test-driven.

First, I verified the installed AgentScope 2.0 API by introspection instead of assuming old examples still worked. AgentScope is moving quickly, so this prevented the project from being built on outdated import paths or old message types.

Then I implemented the pure memory-ranking layer first. That gave me deterministic tests for:

- time decay
- memory ranking
- profile merge behavior
- empty/null profile values acting as removals

Only after that did I wire the live pieces: DashScope models, Mem0Middleware, Qdrant, Postgres, FastAPI endpoints, tools, and the web UI.

The support tools are deliberately product-shaped:

- `knowledge_search` answers shop policy questions from tenant-scoped FAQ rows
- `human_handoff` creates an auditable ticket when the agent should escalate
- memory admin endpoints let the demo search, add, update, list history, and forget memories

## The hardest bugs

The hardest bugs were not the glamorous ones.

### 1. API drift

Agent frameworks change quickly. A small mismatch in a message class or model constructor can break the whole agent path. The fix was to treat the installed runtime as the source of truth and confirm by introspection before coding.

### 2. Memory routing

Memory had to be scoped by both tenant and customer. It was not enough for the agent to remember something; it had to remember it for the right customer under the right shop. The simple `user_id=customer_id` and `agent_id=tenant_id` mapping became the core contract.

### 3. Deployment streaming timeouts

The live Alibaba Cloud deployment uses nginx in front of the app container. Long streamed chat responses can fail if proxy buffering and read timeouts are wrong. The deployed nginx path needed long read/send timeouts and buffering disabled for `/api/chat`, otherwise the app could be healthy while the chat request returned a 502.

### 4. Demo UX

The first UI versions were too hard to judge. The memory was real, but it was not obvious enough. The final UI became more of a "live inspector": the chat is still central, but the right side shows memory, profile, knowledge, handoff, and runtime evidence.

## What judges can test

The demo is designed around repeatable scenarios:

1. Pick **New Customer B**.
2. Tell the agent: `I'm JOY, 18 YO`.
3. Start a new visible session.
4. Ask: `What do you remember about me?`
5. Switch to another customer and verify the memory does not leak.
6. Ask a policy question and check that the answer comes from the tenant knowledge base.
7. Trigger a complaint and verify that a human handoff ticket is created.

Those are not separate scripted pages. They exercise the same `/api/chat`, memory, knowledge, and handoff paths.

## What I am proud of

I am proud that DOSClaw-Qwen is small enough for a hackathon but still has real system boundaries:

- Qwen Cloud powers both chat and embeddings.
- AgentScope 2.0 runs the agent instead of a one-off prompt function.
- Mem0Middleware provides real episodic memory.
- Qdrant stores semantic memory vectors.
- Postgres stores structured profile and support operations data.
- The UI makes the memory path visible instead of hiding it.
- The live Alibaba deployment is verified with smoke tests after updates.

That combination makes the project feel less like a chatbot demo and more like the smallest useful version of a support memory service.

## What I learned

The biggest lesson is that memory quality is not only a model problem. It is a product and systems problem.

An agent needs:

- retrieval that finds the right facts
- scoping that prevents cross-customer leakage
- structured memory for facts that need auditability
- episodic memory for conversational context
- consent and forgetting controls
- UI evidence so humans can debug trust

Qwen Cloud made it possible to keep the reasoning and embedding path in one ecosystem. AgentScope gave the project an agent runtime. Mem0Middleware gave the project a real memory engine. But the product only became understandable when those pieces were exposed clearly in the UI and verified through live scenarios.

## What is next

The next step is to turn DOSClaw-Qwen from a hackathon demo into a deployable SME support memory service:

- better memory consolidation
- richer recall-quality analytics
- staff assignment and SLA timers for handoff tickets
- more tenant onboarding flows
- stronger customer consent and forgetting UX
- production deployment options for real shops

The core idea stays the same: customer-support AI should not only answer well. It should remember responsibly.

Live demo: http://8.219.211.170/

GitHub: https://github.com/JOY/DOSClaw-Qwen

Qwen Cloud proof code: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

Architecture: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg

Tags: #QwenCloud #AlibabaCloud #AgentScope #MemoryAgent #AIHackathon #FastAPI #Qdrant #Postgres

## Vietnamese

# Xây dựng DOSClaw-Qwen: hành trình kỹ thuật phía sau một Qwen Cloud MemoryAgent thật

Phần lớn demo chatbot hackathon nhìn khá thuyết phục trong một cuộc hội thoại. Câu hỏi khó hơn là: chuyện gì xảy ra sau khi refresh tab, khách quay lại ngày hôm sau, hoặc một khách khác dùng cùng tài khoản shop?

Đó là vấn đề tôi muốn DOSClaw-Qwen trả lời. Đây là một agent hỗ trợ khách hàng đa ngôn ngữ cho SME, được xây dựng cho Global AI Hackathon Series with Qwen Cloud. Mục tiêu không chỉ là gọi một model. Mục tiêu là xây một memory system nhỏ nhưng thật: có thể nhớ khách hàng qua nhiều session, giữ đúng ranh giới tenant/customer, trả lời dựa trên knowledge của shop, và cho giám khảo thấy chính xác memory nào đã được recall trước khi agent trả lời.

Live demo hiện chạy tại:

http://8.219.211.170/

Public repository:

https://github.com/JOY/DOSClaw-Qwen

## Vì sao bài toán này không chỉ là chatbot

Kịch bản sản phẩm rất đời thường: một quán cafe, phòng khám, tiệm sửa chữa, hoặc local store nói chuyện với khách quen mỗi ngày.

Một support agent hữu ích nên nhớ các thông tin như:

- khách thích oat milk
- khách không uống được sữa
- khách đã mua sản phẩm gì lần trước
- một complaint vẫn đang chờ nhân viên xử lý

Nhưng memory cũng nguy hiểm nếu nó là global hoặc bị giấu đi. Nếu Customer A nói "tôi dị ứng sữa", Customer B không được kế thừa thông tin đó. Nếu agent nói "tôi nhớ bạn", UI phải cho thấy nó nhớ gì và memory đó đang nằm ở đâu. Vì vậy constraint thiết kế là:

> DOSClaw-Qwen phải hành xử như một support agent có trí nhớ, nhưng trí nhớ đó phải scoped, visible, auditable, và testable.

## Kiến trúc hệ thống

App deploy là một Python application standalone, không phải một mock frontend bọc quanh prompt ẩn. Main path:

```text
Browser UI
  -> FastAPI /api/chat
  -> ChatService
       1. Load tenant + customer profile từ Postgres
       2. Kiểm tra memory consent
       3. Recall episodic memory qua Mem0Middleware
       4. Build support context gọn
       5. Gọi AgentScope 2.0 agent dùng Qwen Cloud
       6. Cho tools search knowledge hoặc tạo human handoff
       7. Persist memory/profile updates sau reply
  -> Stream answer + memory/model/tool metadata về UI
```

Runtime stack:

- **Agent runtime:** AgentScope 2.0
- **Chat model:** Qwen Cloud / DashScope `qwen3.6-plus`
- **Embedding model:** Qwen Cloud / DashScope `text-embedding-v4` với 1024 dimensions
- **Episodic memory:** Mem0Middleware
- **Vector store cho mem0:** Qdrant
- **Structured state:** Postgres cho tenants, customers, profiles, FAQ rows, analytics, và handoff tickets
- **API và UI:** FastAPI cùng static judge-facing web UI
- **Deployment:** Alibaba Cloud Elastic Container Instance với app, Postgres, Qdrant, và nginx sidecars

Architecture diagram nằm trong repo:

https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg

## Memory design: hai lớp, một ranh giới

Quyết định quan trọng nhất là không xem "memory" như một cái bucket mơ hồ. DOSClaw-Qwen dùng hai lớp.

### 1. Structured profile memory

Structured profile memory lưu các fact bền vững mà business nên hiển thị và audit được, ví dụ:

```json
{
  "name": "Linh",
  "prefers": "oat milk lattes",
  "lactose_intolerant": true,
  "last_order": "oat latte + almond croissant"
}
```

Lớp này phù hợp với các fact cần ổn định trong UI và dễ edit hoặc forget.

### 2. Episodic memory qua Mem0Middleware

Episodic memory lưu conversational memories và semantic recall. Đây là nơi Qwen Cloud embeddings quan trọng: memories và FAQ rows có thể được retrieve theo nghĩa, không chỉ exact keyword.

Multi-user boundary được giữ đơn giản và rõ ràng:

```text
mem0 user_id  = customer_id
mem0 agent_id = tenant_id
```

Nghĩa là cùng một backend có thể phục vụ nhiều shop và nhiều khách mà không trộn recall. Giám khảo có thể dạy "New Customer B" một tên và tuổi, start một visible session mới, rồi hỏi agent còn nhớ gì. Sau đó chuyển về "Returning Customer A" để kiểm tra preference cafe seeded vẫn tách biệt.

## Qwen Cloud được dùng ở đâu

Qwen Cloud được dùng ở hai nơi:

1. **Reasoning và response generation** qua DashScope chat model.
2. **Embeddings** cho semantic memory và knowledge search.

Proof code cho phần Qwen Cloud model wiring:

https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

Một constraint quan trọng là Mem0Middleware không được âm thầm fallback sang OpenAI path. Memory engine phải chạy qua cùng DashScope/Qwen stack với agent. Việc này làm integration phức tạp hơn, nhưng giúp demo trung thực: model, embeddings, memory recall, và visible runtime metadata đều trỏ về cùng một Qwen Cloud-based system.

Live runtime endpoint expose proof như sau:

```json
{
  "chat_model": "qwen3.6-plus",
  "embedding_model": "text-embedding-v4",
  "embedding_dimensions": 1024,
  "agent_runtime": "AgentScope 2.0",
  "memory_engine": "Mem0Middleware",
  "vector_store": "Qdrant server 127.0.0.1:6333",
  "memory_scope": "tenant_id + customer_id"
}
```

## Vì sao UI expose internals

Với memory-agent demo, một câu trả lời mượt là chưa đủ. Giám khảo cần biết hệ thống thật sự recall gì hay chỉ sinh ra một câu nghe hợp lý.

Vì vậy UI hiển thị:

- tenant/shop hiện tại
- customer persona đang chọn
- memory block đã recall
- structured customer profile
- Qwen model và embedding model đang chạy
- memory backend
- knowledge base search results
- human handoff tickets
- memory controls như search, add, update, history, forget, forget all

Đây không chỉ là lựa chọn design. Đây là lựa chọn debugging và trust. Nếu recall fail, lỗi hiện ra. Nếu chọn nhầm customer, scope hiện ra. Nếu agent dùng knowledge search hoặc handoff tool, evidence cũng hiện ra.

## Quá trình build

Thứ tự implement được làm theo hướng test-driven.

Đầu tiên, tôi verify AgentScope 2.0 API đã cài bằng introspection thay vì tin rằng example cũ vẫn đúng. AgentScope thay đổi nhanh, nên bước này giúp tránh build dự án trên import path hoặc message type lỗi thời.

Sau đó tôi implement pure memory-ranking layer trước. Phần này có deterministic tests cho:

- time decay
- memory ranking
- profile merge behavior
- empty/null profile values được xử lý như removals

Chỉ sau đó mới wire các phần live: DashScope models, Mem0Middleware, Qdrant, Postgres, FastAPI endpoints, tools, và web UI.

Support tools được thiết kế theo hướng sản phẩm:

- `knowledge_search` trả lời câu hỏi policy từ tenant-scoped FAQ rows
- `human_handoff` tạo ticket có thể audit khi agent cần escalate
- memory admin endpoints cho phép demo search, add, update, list history, và forget memories

## Những lỗi khó nhất

Các lỗi khó nhất không phải lúc nào cũng hào nhoáng.

### 1. API drift

Agent frameworks thay đổi nhanh. Chỉ cần lệch một message class hoặc model constructor là toàn bộ agent path hỏng. Cách xử lý là xem installed runtime là source of truth và confirm bằng introspection trước khi code.

### 2. Memory routing

Memory phải được scope theo cả tenant và customer. Agent nhớ được một thứ là chưa đủ; nó phải nhớ đúng cho khách đúng trong shop đúng. Mapping `user_id=customer_id` và `agent_id=tenant_id` trở thành core contract.

### 3. Deployment streaming timeouts

Live Alibaba Cloud deployment dùng nginx phía trước app container. Streamed chat response dài có thể fail nếu proxy buffering và read timeout sai. Nginx path cho `/api/chat` cần read/send timeout dài và tắt buffering; nếu không, app vẫn healthy nhưng chat request trả 502.

### 4. Demo UX

Các bản UI đầu tiên quá khó judge. Memory là thật, nhưng chưa đủ rõ. UI cuối cùng trở thành một "live inspector": chat vẫn là trung tâm, nhưng bên phải hiển thị memory, profile, knowledge, handoff, và runtime evidence.

## Giám khảo có thể test gì

Demo được thiết kế quanh các scenario lặp lại được:

1. Chọn **New Customer B**.
2. Nói với agent: `I'm JOY, 18 YO`.
3. Start một visible session mới.
4. Hỏi: `What do you remember about me?`
5. Chuyển sang customer khác để kiểm tra memory không leak.
6. Hỏi một policy question và kiểm tra answer đến từ tenant knowledge base.
7. Trigger complaint và xác nhận human handoff ticket được tạo.

Đây không phải các trang script riêng. Chúng exercise cùng `/api/chat`, memory, knowledge, và handoff paths.

## Điều tôi tự hào

Tôi tự hào vì DOSClaw-Qwen đủ nhỏ cho hackathon nhưng vẫn có system boundaries thật:

- Qwen Cloud powers cả chat và embeddings.
- AgentScope 2.0 chạy agent thay vì một prompt function tự chế.
- Mem0Middleware cung cấp episodic memory thật.
- Qdrant lưu semantic memory vectors.
- Postgres lưu structured profile và support operations data.
- UI làm memory path visible thay vì giấu đi.
- Live Alibaba deployment được verify bằng smoke tests sau mỗi update.

Tổ hợp này làm project giống phiên bản nhỏ nhất có ích của một support memory service hơn là một chatbot demo.

## Điều tôi học được

Bài học lớn nhất là memory quality không chỉ là model problem. Nó là product và systems problem.

Một agent cần:

- retrieval tìm đúng fact
- scoping để tránh cross-customer leakage
- structured memory cho fact cần auditability
- episodic memory cho conversational context
- consent và forgetting controls
- UI evidence để con người debug trust

Qwen Cloud giúp giữ reasoning và embedding path trong cùng một ecosystem. AgentScope cho project một agent runtime. Mem0Middleware cho project một memory engine thật. Nhưng sản phẩm chỉ trở nên dễ hiểu khi các phần đó được expose rõ trong UI và verify qua live scenarios.

## Tiếp theo

Bước tiếp theo là biến DOSClaw-Qwen từ hackathon demo thành một SME support memory service có thể deploy thật:

- memory consolidation tốt hơn
- recall-quality analytics sâu hơn
- staff assignment và SLA timers cho handoff tickets
- nhiều tenant onboarding flows hơn
- customer consent và forgetting UX mạnh hơn
- production deployment options cho shop thật

Core idea vẫn giữ nguyên: customer-support AI không chỉ nên trả lời tốt. Nó nên nhớ một cách có trách nhiệm.

Live demo: http://8.219.211.170/

GitHub: https://github.com/JOY/DOSClaw-Qwen

Qwen Cloud proof code: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

Architecture: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg

Tags: #QwenCloud #AlibabaCloud #AgentScope #MemoryAgent #AIHackathon #FastAPI #Qdrant #Postgres
