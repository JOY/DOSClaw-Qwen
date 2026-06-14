from fastapi.testclient import TestClient

from dosclaw_qwen.app import create_app


class FakeChatService:
    async def list_customers(self, tenant_id):
        return [{"id": "cust_a", "name": "Returning Customer A"}]

    async def chat_events(self, tenant_id, customer_id, message):
        yield {"kind": "memory", "text": "Customer profile: oat milk"}
        yield {"kind": "model_info", "text": "Qwen Cloud: qwen3.6-plus"}
        yield {"kind": "message", "text": "Try an oat latte."}

    async def consolidate(self, tenant_id, customer_id):
        return 0


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
    assert '{"kind": "message", "text": "Try an oat latte."}' in response.text
