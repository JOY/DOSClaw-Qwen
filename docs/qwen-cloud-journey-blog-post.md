# Building DOSClaw-Qwen: A Real MemoryAgent Journey With Qwen Cloud

Publication draft for the optional Blog Post Prize.

Publish this on LinkedIn, Dev.to, Medium, Hashnode, or another public blog/social platform, then paste the published URL into the Devpost field.

## English

# Building DOSClaw-Qwen: A Real MemoryAgent Journey With Qwen Cloud

For the Global AI Hackathon Series with Qwen Cloud, I wanted to build something that judges could test instead of something they could only watch. The goal became DOSClaw-Qwen: a multilingual customer-support agent for small and medium businesses that remembers each customer across sessions without mixing people together.

The idea came from a simple support scenario. A cafe, clinic, repair shop, or local service provider should not have to ask the same returning customer about allergies, preferences, previous orders, or unresolved complaints every time they start a new chat. At the same time, memory can become risky if it is global, invisible, or impossible to audit. A useful support agent needs memory, but it also needs boundaries.

That is why DOSClaw-Qwen was built as a MemoryAgent. The demo uses Qwen Cloud for both reasoning and embeddings, AgentScope 2.0 for the agent runtime, Mem0Middleware for episodic memory, and a structured profile layer for durable customer facts. The memory scope is intentionally simple:

```text
mem0 user_id = customer_id
mem0 agent_id = tenant_id
```

This means Customer A can teach the agent a preference, start a new visible session, and ask what the agent remembers. Customer B does not inherit that memory. The demo is designed around that boundary because customer isolation is the difference between a useful SME support agent and a scripted chatbot.

The runtime is a standalone Python application. FastAPI serves the API and web UI. AgentScope runs the support agent and tools. Qwen Cloud / DashScope provides `qwen3.6-plus` for chat reasoning and `text-embedding-v4` for semantic memory and FAQ search. Mem0Middleware stores episodic memory in Qdrant, while Postgres with pgvector stores tenants, customers, structured profiles, FAQ rows, and human handoff tickets. The live app runs on Alibaba Cloud Elastic Container Instance with app, Postgres, Qdrant, and nginx sidecars.

The most important UI choice was making memory visible. The web demo does not only show an answer. It also shows the recalled memory block, the active Qwen model, the embedding model, the memory backend, the tenant/customer scope, and tool calls such as `knowledge_search` or `human_handoff`. That matters because memory agents are easy to fake if the retrieval path is hidden. For a judging demo, the agent should show what it remembered before it answers.

The hardest engineering challenge was keeping the system real while keeping it small enough for a hackathon. AgentScope 2.0 APIs are moving quickly, so we verified the installed runtime by introspection before wiring the model, tools, and middleware. Mem0 also had to use the same DashScope/Qwen path instead of quietly falling back to OpenAI. On the deployment side, Alibaba Cloud ECI restarts made us treat smoke tests as part of the product: after each live update, we rechecked runtime metadata, memory recall, customer isolation, FAQ grounding, and handoff creation.

What I am most proud of is that the demo has real behavior behind the buttons. It can remember a name and age across sessions, keep another customer clean, ground policy answers in tenant FAQ data, and create an auditable handoff ticket when the conversation needs a human. It is not just a prompt. It is a small but complete memory system.

The biggest lesson was that support memory needs two layers. Episodic memory is flexible and conversational, but structured profile memory is better for durable facts that must be displayed, updated, and audited. Qwen Cloud embeddings help the agent search across past interactions and FAQ rows, while the profile layer gives the UI a stable record of what the business thinks it knows about a customer.

Next, I want to turn DOSClaw-Qwen into a deployable support memory service: improve memory consolidation, add staff assignment and SLA timers for handoff tickets, add richer recall-quality analytics, and make self-serve onboarding easier for real SME teams.

Live demo: http://8.219.211.170/

GitHub: https://github.com/JOY/DOSClaw-Qwen

Qwen Cloud proof code: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

Architecture: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg

Tags: #QwenCloud #AlibabaCloud #AgentScope #MemoryAgent #AIHackathon #FastAPI #Qdrant #Postgres

## Vietnamese

# Xây dựng DOSClaw-Qwen: Hành trình làm MemoryAgent thật với Qwen Cloud

Với Global AI Hackathon Series with Qwen Cloud, tôi muốn xây dựng một sản phẩm mà giám khảo có thể tự tay kiểm thử, không phải chỉ xem một demo đã được script sẵn. Từ đó, DOSClaw-Qwen ra đời: một agent hỗ trợ khách hàng đa ngôn ngữ cho SME, có khả năng nhớ từng khách hàng qua nhiều phiên mà không trộn dữ liệu giữa các khách hàng.

Ý tưởng bắt đầu từ một tình huống support rất đời thường. Một quán cafe, phòng khám, tiệm sửa chữa, hay một dịch vụ địa phương không nên hỏi lại khách quen về dị ứng, sở thích, đơn hàng trước đó, hay khiếu nại chưa xử lý mỗi lần họ bắt đầu chat mới. Nhưng memory cũng có rủi ro nếu nó là bộ nhớ chung, không hiển thị rõ, hoặc không thể audit. Một support agent hữu ích cần có trí nhớ, nhưng trí nhớ đó phải có ranh giới.

Đó là lý do DOSClaw-Qwen được xây dựng theo hướng MemoryAgent. Demo dùng Qwen Cloud cho cả reasoning và embeddings, AgentScope 2.0 cho agent runtime, Mem0Middleware cho episodic memory, và một structured profile layer cho các thông tin khách hàng bền vững. Memory scope được thiết kế rất rõ:

```text
mem0 user_id = customer_id
mem0 agent_id = tenant_id
```

Nghĩa là Customer A có thể dạy agent một sở thích, bắt đầu một session mới, rồi hỏi agent còn nhớ gì. Customer B sẽ không bị kế thừa memory của Customer A. Demo xoay quanh ranh giới này vì customer isolation là điểm khác nhau giữa một SME support agent dùng được và một chatbot đã script sẵn.

Runtime là một ứng dụng Python standalone. FastAPI phục vụ API và web UI. AgentScope chạy support agent và tools. Qwen Cloud / DashScope cung cấp `qwen3.6-plus` cho chat reasoning và `text-embedding-v4` cho semantic memory và FAQ search. Mem0Middleware lưu episodic memory trong Qdrant, còn Postgres với pgvector lưu tenants, customers, structured profiles, FAQ rows, và human handoff tickets. Bản live chạy trên Alibaba Cloud Elastic Container Instance với các sidecar app, Postgres, Qdrant, và nginx.

Lựa chọn UI quan trọng nhất là làm memory trở nên thấy được. Web demo không chỉ hiện câu trả lời. Nó còn hiện memory block đã recall, Qwen model đang dùng, embedding model, memory backend, tenant/customer scope, và tool calls như `knowledge_search` hoặc `human_handoff`. Điều này quan trọng vì memory agent rất dễ bị biến thành một prompt demo nếu retrieval path bị ẩn đi. Với một hackathon demo, agent nên cho thấy nó đã nhớ gì trước khi trả lời.

Thách thức kỹ thuật lớn nhất là giữ hệ thống thật trong khi vẫn đủ nhỏ gọn cho hackathon. AgentScope 2.0 API đang thay đổi nhanh, nên chúng tôi verify runtime đã cài bằng introspection trước khi wire model, tools, và middleware. Mem0 cũng phải đi qua cùng DashScope/Qwen path thay vì âm thầm fallback sang OpenAI. Về deployment, Alibaba Cloud ECI có quá trình restart sau mỗi lần update, nên smoke test trở thành một phần của sản phẩm: sau mỗi live update, chúng tôi kiểm tra lại runtime metadata, memory recall, customer isolation, FAQ grounding, và handoff creation.

Điều tôi tự hào nhất là demo có hành vi thật phía sau các nút bấm. Nó có thể nhớ tên và tuổi qua session mới, giữ Customer B sạch khỏi memory của Customer A, trả lời policy dựa trên FAQ của tenant, và tạo handoff ticket có thể audit khi cần người xử lý. Nó không chỉ là một prompt. Nó là một memory system nhỏ nhưng hoàn chỉnh.

Bài học lớn nhất là support memory cần hai lớp. Episodic memory linh hoạt và giống hội thoại, nhưng structured profile memory tốt hơn cho các fact bền vững cần hiển thị, cập nhật, và audit. Qwen Cloud embeddings giúp agent tìm lại tương tác cũ và FAQ rows, còn profile layer cho UI một bản ghi ổn định về những gì doanh nghiệp tin là mình biết về khách hàng.

Bước tiếp theo là biến DOSClaw-Qwen thành một support memory service có thể triển khai thực tế: cải thiện memory consolidation, thêm phân công nhân viên và SLA timer cho handoff tickets, thêm analytics sâu hơn về chất lượng recall, và làm self-serve onboarding dễ dùng hơn cho các SME team thật.

Live demo: http://8.219.211.170/

GitHub: https://github.com/JOY/DOSClaw-Qwen

Qwen Cloud proof code: https://github.com/JOY/DOSClaw-Qwen/blob/main/dosclaw_qwen/model.py

Architecture: https://github.com/JOY/DOSClaw-Qwen/blob/main/docs/architecture.svg

Tags: #QwenCloud #AlibabaCloud #AgentScope #MemoryAgent #AIHackathon #FastAPI #Qdrant #Postgres
