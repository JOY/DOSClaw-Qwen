# Building DOSClaw-Qwen: a small memory agent that became more real than I expected

Publication draft for the optional Blog Post Prize.

Publish this on Substack, LinkedIn, Dev.to, Medium, Hashnode, or another public blog/social platform, then paste the published URL into the Devpost field.

## English

# Building DOSClaw-Qwen: a small memory agent that became more real than I expected

I started DOSClaw-Qwen with a simple question: can a customer-support agent remember useful things without becoming a creepy, global, impossible-to-debug memory blob?

For the Global AI Hackathon Series with Qwen Cloud, I wanted to build something that judges could actually poke at. Not a scripted chat. Not a single happy-path prompt. I wanted a demo where someone could teach the agent a fact, start a new session, switch customers, and see whether memory was really scoped correctly.

The result is DOSClaw-Qwen, a multilingual support agent for small businesses. The live demo is here:

http://8.219.211.170/

The code is here:

https://github.com/JOY/DOSClaw-Qwen

## The product idea

The use case is very ordinary, and that is why I like it.

Imagine a cafe, clinic, repair shop, or local store. A returning customer should not have to repeat the same context every time:

- "I prefer oat milk."
- "I am lactose intolerant."
- "My last order was an oat latte."
- "I already complained about this issue."

At the same time, memory has to be careful. Customer A's allergies must not leak into Customer B's conversation. A shop should be able to inspect what the agent remembers. A customer should be able to ask the system to forget.

That became the shape of the project: a support agent with real memory, but with visible boundaries.

## The stack I ended up using

The app is a standalone Python project. The core stack is:

- FastAPI for the backend and web UI
- AgentScope 2.0 for the agent runtime
- Qwen Cloud / DashScope `qwen3.6-plus` for chat
- Qwen Cloud / DashScope `text-embedding-v4` for embeddings
- Mem0Middleware for episodic memory
- Qdrant for memory vectors
- Postgres for customer profiles, FAQ rows, analytics, and handoff tickets
- Alibaba Cloud Elastic Container Instance for the live deployment

The high-level flow is:

```text
User message
  -> FastAPI /api/chat
  -> load tenant + customer profile
  -> recall memory with Mem0Middleware
  -> build context for AgentScope
  -> call Qwen Cloud
  -> optionally use knowledge_search or human_handoff
  -> stream answer + memory/model/tool evidence back to the UI
```

That last part matters. The UI does not only show the assistant's answer. It also shows the recalled memory, the current customer profile, the active model, the memory backend, and tool evidence. I wanted the demo to make memory visible instead of hiding it behind a nice sentence.

## The memory design

The first thing I learned was that "memory" is too vague as a product feature. I split it into two layers.

Structured profile memory is for durable facts:

```json
{
  "name": "Linh",
  "prefers": "oat milk lattes",
  "lactose_intolerant": true,
  "last_order": "oat latte + almond croissant"
}
```

Episodic memory is for conversational recall. That path goes through Mem0Middleware, Qdrant, and Qwen Cloud embeddings.

The important boundary is:

```text
mem0 user_id  = customer_id
mem0 agent_id = tenant_id
```

This is the small line that makes the demo useful. A judge can teach "New Customer B" a name and age, start a new visible session, and ask what the agent remembers. Then they can switch to another customer and check that the memory does not leak.

## Where Qwen Cloud fits

Qwen Cloud is not just a final text-generation call in this project.

It powers the agent response through DashScope chat, and it powers semantic search through embeddings. That means the same Qwen-based stack is used for both reasoning and memory retrieval.

The proof code is here:

https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

The live runtime endpoint exposes the important details:

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

## What was harder than expected

The hard parts were not dramatic. They were the boring things that make a demo real.

AgentScope 2.0 had to be checked against the installed runtime, not old examples. A small API mismatch can break the whole agent path.

Mem0 had to stay on the Qwen/DashScope path. I did not want the memory layer quietly using a different provider while the main agent used Qwen Cloud.

The live Alibaba deployment also exposed a classic streaming problem. The app could be healthy, but streamed chat could still fail behind nginx if the proxy timeout and buffering settings were wrong. Fixing `/api/chat` streaming made the demo feel much more production-shaped.

And finally, the UI took more work than I expected. At first the memory was real, but it was not obvious. The current UI is closer to a live inspector: chat in the middle, memory/profile/knowledge/runtime evidence on the side.

## What you can test in the demo

The easiest demo path is:

1. Choose **New Customer B**.
2. Say: `I'm JOY, 18 YO`.
3. Start a new visible session.
4. Ask: `What do you remember about me?`
5. Switch to another customer and verify that the memory does not leak.
6. Ask a shop-policy question and check the knowledge-base answer.
7. Trigger a complaint and see a human handoff ticket appear.

That path exercises the real backend. It is not a separate scripted page.

## What I am happy with

I am happy that the project stayed small but honest.

It uses Qwen Cloud for chat and embeddings. AgentScope runs the agent. Mem0Middleware handles episodic memory. Qdrant stores memory vectors. Postgres stores the structured support state. The UI shows the memory path instead of asking users to trust it blindly.

It is not a full product yet, but it feels like the smallest real version of one.

## What I learned

My biggest takeaway is that memory quality is not only about the model.

It is about boundaries, retrieval, consent, forgetting, debugging, and product design. A memory agent needs to answer well, but it also needs to show why it answered that way.

That is what I like most about this project. DOSClaw-Qwen is not trying to be mysterious. It tries to make the memory visible.

## What is next

If I keep pushing it after the hackathon, I would focus on:

- better memory consolidation
- better recall-quality analytics
- staff assignment for handoff tickets
- stronger consent and forgetting UX
- easier onboarding for real small businesses

Customer-support AI should not just answer quickly. It should remember responsibly.

Live demo: http://8.219.211.170/

GitHub: https://github.com/JOY/DOSClaw-Qwen

Qwen Cloud proof code: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

Architecture: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg

Tags: #QwenCloud #AlibabaCloud #AgentScope #MemoryAgent #AIHackathon #FastAPI #Qdrant #Postgres

## Vietnamese

# Xây dựng DOSClaw-Qwen: một memory agent nhỏ nhưng thật hơn mình nghĩ

Mình bắt đầu DOSClaw-Qwen từ một câu hỏi khá đơn giản: liệu một support agent có thể nhớ những điều hữu ích về khách hàng mà không biến thành một cục memory chung chung, khó kiểm soát, và không ai debug nổi không?

Với Global AI Hackathon Series with Qwen Cloud, mình muốn làm một thứ giám khảo có thể tự tay thử. Không phải một đoạn chat được script sẵn. Không phải một prompt chỉ chạy đúng một happy path. Mình muốn một demo nơi người dùng có thể dạy agent một fact, mở session mới, đổi customer, rồi nhìn xem memory có thật sự được scope đúng không.

Kết quả là DOSClaw-Qwen, một support agent đa ngôn ngữ cho SME. Live demo ở đây:

http://8.219.211.170/

Code ở đây:

https://github.com/JOY/DOSClaw-Qwen

## Ý tưởng sản phẩm

Use case rất đời thường, và đó là lý do mình thích nó.

Hãy tưởng tượng một quán cafe, phòng khám, tiệm sửa chữa, hoặc local store. Khách quen không nên phải lặp lại cùng một context mỗi lần chat:

- "Mình thích oat milk."
- "Mình không uống được sữa."
- "Order lần trước của mình là oat latte."
- "Mình đã complain về vấn đề này rồi."

Nhưng memory cũng phải cẩn thận. Dị ứng của Customer A không được leak sang Customer B. Shop phải inspect được agent đang nhớ gì. Khách hàng cũng nên có quyền yêu cầu quên.

Vì vậy project đi theo hướng: một support agent có trí nhớ thật, nhưng trí nhớ đó phải có ranh giới rõ ràng.

## Stack mình dùng

App là một Python project standalone. Core stack gồm:

- FastAPI cho backend và web UI
- AgentScope 2.0 cho agent runtime
- Qwen Cloud / DashScope `qwen3.6-plus` cho chat
- Qwen Cloud / DashScope `text-embedding-v4` cho embeddings
- Mem0Middleware cho episodic memory
- Qdrant cho memory vectors
- Postgres cho customer profiles, FAQ rows, analytics, và handoff tickets
- Alibaba Cloud Elastic Container Instance cho live deployment

Luồng chính:

```text
User message
  -> FastAPI /api/chat
  -> load tenant + customer profile
  -> recall memory bằng Mem0Middleware
  -> build context cho AgentScope
  -> gọi Qwen Cloud
  -> có thể dùng knowledge_search hoặc human_handoff
  -> stream answer + memory/model/tool evidence về UI
```

Đoạn cuối rất quan trọng. UI không chỉ hiện câu trả lời của assistant. Nó còn hiện memory đã recall, customer profile hiện tại, model đang dùng, memory backend, và tool evidence. Mình muốn demo làm memory trở nên nhìn thấy được, thay vì giấu nó sau một câu trả lời nghe có vẻ hay.

## Memory design

Điều đầu tiên mình học được là "memory" quá mơ hồ nếu xem nó như một feature duy nhất. Mình tách nó thành hai lớp.

Structured profile memory dành cho các fact bền vững:

```json
{
  "name": "Linh",
  "prefers": "oat milk lattes",
  "lactose_intolerant": true,
  "last_order": "oat latte + almond croissant"
}
```

Episodic memory dành cho conversational recall. Path này đi qua Mem0Middleware, Qdrant, và Qwen Cloud embeddings.

Ranh giới quan trọng là:

```text
mem0 user_id  = customer_id
mem0 agent_id = tenant_id
```

Chỉ một mapping nhỏ này làm demo trở nên đáng test. Giám khảo có thể dạy "New Customer B" một tên và tuổi, mở visible session mới, rồi hỏi agent nhớ gì. Sau đó đổi sang customer khác để kiểm tra memory không leak.

## Qwen Cloud nằm ở đâu

Qwen Cloud không chỉ là bước sinh câu trả lời cuối cùng.

Nó dùng cho agent response qua DashScope chat, và dùng cho semantic search qua embeddings. Nghĩa là cùng một Qwen-based stack phục vụ cả reasoning lẫn memory retrieval.

Proof code ở đây:

https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

Live runtime endpoint expose các phần quan trọng:

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

## Phần khó hơn mình nghĩ

Những phần khó nhất không hẳn là thứ nghe hoành tráng. Chúng là các chi tiết hơi nhàm nhưng làm demo trở nên thật.

AgentScope 2.0 phải được check theo runtime đang cài, không thể bê nguyên example cũ. Chỉ lệch một message class hoặc constructor là agent path có thể hỏng.

Mem0 cũng phải đi đúng Qwen/DashScope path. Mình không muốn memory layer âm thầm dùng provider khác trong khi main agent dùng Qwen Cloud.

Live deployment trên Alibaba cũng lộ ra một lỗi streaming rất quen: app vẫn healthy, nhưng streamed chat vẫn có thể fail phía sau nginx nếu timeout và buffering sai. Fix `/api/chat` streaming làm demo giống một hệ thống production hơn rất nhiều.

Cuối cùng là UI. Ban đầu memory là thật, nhưng nhìn chưa đủ rõ. UI hiện tại giống một live inspector hơn: chat ở giữa, còn memory/profile/knowledge/runtime evidence nằm bên cạnh.

## Có thể test gì trong demo

Demo path dễ nhất:

1. Chọn **New Customer B**.
2. Gõ: `I'm JOY, 18 YO`.
3. Start một visible session mới.
4. Hỏi: `What do you remember about me?`
5. Đổi sang customer khác để kiểm tra memory không leak.
6. Hỏi một câu về policy của shop và xem câu trả lời từ knowledge base.
7. Trigger complaint và xem human handoff ticket xuất hiện.

Path này chạy qua backend thật. Nó không phải một trang script riêng.

## Điều mình thấy vui nhất

Mình vui vì project vẫn nhỏ, nhưng không bị giả.

Nó dùng Qwen Cloud cho chat và embeddings. AgentScope chạy agent. Mem0Middleware xử lý episodic memory. Qdrant lưu memory vectors. Postgres lưu structured support state. UI cho thấy memory path thay vì bắt người dùng tin mù.

Nó chưa phải full product, nhưng đã giống phiên bản nhỏ nhất có thật của một sản phẩm.

## Mình học được gì

Takeaway lớn nhất của mình là memory quality không chỉ là chuyện model.

Nó là chuyện boundary, retrieval, consent, forgetting, debugging, và product design. Một memory agent cần trả lời tốt, nhưng cũng cần cho con người thấy vì sao nó trả lời như vậy.

Đó là điều mình thích nhất ở DOSClaw-Qwen. Nó không cố tỏ ra bí ẩn. Nó cố làm memory trở nên nhìn thấy được.

## Tiếp theo

Nếu tiếp tục đẩy sau hackathon, mình sẽ tập trung vào:

- memory consolidation tốt hơn
- recall-quality analytics tốt hơn
- staff assignment cho handoff tickets
- consent và forgetting UX rõ hơn
- onboarding dễ hơn cho SME thật

Customer-support AI không chỉ nên trả lời nhanh. Nó nên nhớ một cách có trách nhiệm.

Live demo: http://8.219.211.170/

GitHub: https://github.com/JOY/DOSClaw-Qwen

Qwen Cloud proof code: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

Architecture: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg

Tags: #QwenCloud #AlibabaCloud #AgentScope #MemoryAgent #AIHackathon #FastAPI #Qdrant #Postgres
