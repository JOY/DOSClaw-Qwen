from fastapi.testclient import TestClient

from dosclaw_qwen.app import create_app


class FakeChatService:
    def __init__(self):
        self.deleted = []

    async def list_customers(self, tenant_id):
        return [{"id": "cust_a", "name": "Returning Customer A"}]

    async def chat_events(self, tenant_id, customer_id, message):
        yield {"kind": "memory", "text": "Customer profile: oat milk"}
        yield {"kind": "model_info", "text": "Qwen Cloud: qwen3.6-plus"}
        yield {"kind": "tool_info", "text": "Tool: knowledge_search"}
        yield {"kind": "message", "text": "Try an oat latte."}

    async def consolidate(self, tenant_id, customer_id):
        return 0

    async def list_memories(self, tenant_id, customer_id, top_k=20):
        return {
            "profile": {"name": "Linh"},
            "memories": [{"id": "mem_1", "memory": "Linh prefers oat milk."}],
        }

    async def search_memories(self, tenant_id, customer_id, query, top_k=5):
        return {"results": [{"id": "mem_1", "memory": "Linh prefers oat milk.", "score": 0.9}]}

    async def add_memory(self, tenant_id, customer_id, text, infer=True):
        return {"message": "Memory added", "text": text, "infer": infer}

    async def update_memory(self, tenant_id, customer_id, memory_id, text):
        return {"message": "Memory updated", "id": memory_id, "text": text}

    async def get_memory(self, tenant_id, customer_id, memory_id):
        return {"id": memory_id, "memory": "Linh prefers oat milk."}

    async def delete_memory(self, tenant_id, customer_id, memory_id):
        self.deleted.append(memory_id)
        return {"message": "Memory deleted", "id": memory_id}

    async def delete_all_memories(self, tenant_id, customer_id):
        return {"message": "All customer memories deleted", "profile_cleared": True}

    async def memory_history(self, tenant_id, customer_id, memory_id):
        return [{"event": "ADD", "memory_id": memory_id}]

    async def list_knowledge(self, tenant_id):
        return [{"id": 1, "title": "Refund policy", "content": "Escalate refund complaints."}]

    async def search_knowledge(self, tenant_id, query, limit=3):
        return [{"title": "Refund policy", "content": "Escalate refund complaints.", "similarity": 0.91}]


def test_customers_endpoint_uses_chat_service():
    client = TestClient(create_app(chat_service=FakeChatService(), require_login=False))

    response = client.get("/api/customers")

    assert response.status_code == 200
    assert response.json() == [{"id": "cust_a", "name": "Returning Customer A"}]


def test_health_endpoint_identifies_service():
    client = TestClient(create_app(chat_service=FakeChatService(), require_login=False))

    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.json() == {"ok": True, "service": "dosclaw-qwen"}


def test_runtime_endpoint_reports_non_secret_runtime_details():
    client = TestClient(create_app(chat_service=FakeChatService(), require_login=False))

    response = client.get("/api/runtime")

    assert response.status_code == 200
    body = response.json()
    assert body["service"] == "dosclaw-qwen"
    assert body["chat_model"]
    assert body["embedding_model"]
    assert body["agent_runtime"] == "AgentScope 2.0"
    assert body["memory_engine"] == "Mem0Middleware"
    assert "key" not in response.text.lower()


def test_chat_endpoint_streams_ndjson_events():
    client = TestClient(create_app(chat_service=FakeChatService(), require_login=False))

    response = client.post(
        "/api/chat",
        json={"customer_id": "cust_a", "message": "What do you recommend?"},
    )

    assert response.status_code == 200
    assert '{"kind": "memory", "text": "Customer profile: oat milk"}' in response.text
    assert '{"kind": "model_info", "text": "Qwen Cloud: qwen3.6-plus"}' in response.text
    assert '{"kind": "tool_info", "text": "Tool: knowledge_search"}' in response.text
    assert '{"kind": "message", "text": "Try an oat latte."}' in response.text


def test_memory_management_endpoints_delegate_to_chat_service():
    service = FakeChatService()
    client = TestClient(create_app(chat_service=service, require_login=False))

    listed = client.get("/api/memory", params={"customer_id": "cust_a"})
    searched = client.get("/api/memory/search", params={"customer_id": "cust_a", "query": "oat"})
    added = client.post("/api/memory", json={"customer_id": "cust_a", "text": "Linh likes oat milk."})
    updated = client.patch("/api/memory/mem_1", json={"customer_id": "cust_a", "text": "Linh prefers oat milk."})
    fetched = client.get("/api/memory/mem_1", params={"customer_id": "cust_a"})
    history = client.get("/api/memory/mem_1/history", params={"customer_id": "cust_a"})
    deleted = client.delete("/api/memory/mem_1", params={"customer_id": "cust_a"})
    deleted_all = client.delete("/api/memory", params={"customer_id": "cust_a"})

    assert listed.status_code == 200
    assert listed.json()["profile"] == {"name": "Linh"}
    assert searched.json()["results"][0]["score"] == 0.9
    assert added.json()["message"] == "Memory added"
    assert updated.json()["id"] == "mem_1"
    assert fetched.json()["memory"] == "Linh prefers oat milk."
    assert history.json() == [{"event": "ADD", "memory_id": "mem_1"}]
    assert deleted.json()["id"] == "mem_1"
    assert deleted_all.json()["profile_cleared"] is True
    assert service.deleted == ["mem_1"]


def test_knowledge_base_endpoints_expose_list_and_search():
    client = TestClient(create_app(chat_service=FakeChatService(), require_login=False))

    listed = client.get("/api/knowledge")
    searched = client.get("/api/knowledge/search", params={"query": "refund"})

    assert listed.status_code == 200
    assert listed.json()[0]["title"] == "Refund policy"
    assert searched.status_code == 200
    assert searched.json()[0]["similarity"] == 0.91
