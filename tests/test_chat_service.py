import pytest
from agentscope.message import Msg, TextBlock

from dosclaw_qwen import chat_service as chat_service_module
from dosclaw_qwen.chat_service import ChatService


class FakeAgent:
    class State:
        context = []

    state = State()

    async def reply_stream(self, message):
        yield Msg(
            name="assistant",
            role="assistant",
            content=[TextBlock(text="Hello, I can help.")],
        )


class PausedMemoryService:
    def __init__(self):
        self.recorded = False

    async def recall(self, tenant_id, customer_id, message):
        return "Customer profile:\n- Memory consent: paused"

    async def get_consent(self, tenant_id, customer_id):
        return {"customer_id": customer_id, "status": "paused"}

    async def record(self, tenant_id, customer_id, user_text, assistant_text):
        self.recorded = True
        raise AssertionError("Paused customers must not be auto-recorded")


@pytest.mark.asyncio
async def test_chat_events_do_not_auto_record_profile_when_memory_consent_is_paused(monkeypatch):
    captured = {}

    async def fake_build_agent(tenant_id, customer_id, store, mode="both"):
        captured["mode"] = mode
        return FakeAgent()

    monkeypatch.setattr(chat_service_module.agent_module, "build_agent", fake_build_agent)
    memory_service = PausedMemoryService()
    service = ChatService(store=object(), memory_service=memory_service, mem0_admin=object())

    events = [
        event
        async for event in service.chat_events(
            "tenant_demo",
            "cust_a",
            "Please remember that I like oat milk.",
        )
    ]

    assert captured["mode"] == "agent_control"
    assert memory_service.recorded is False
    assert {"kind": "memory_policy", "text": "Memory writes paused for this customer."} in events
    assert {"kind": "message", "text": "Hello, I can help."} in events
