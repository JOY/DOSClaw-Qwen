import pytest

from agentscope.permission import PermissionBehavior
from agentscope.state import AgentState

from dosclaw_qwen import agent as agent_module
from dosclaw_qwen.agent import (
    apply_demo_permission_rules,
    build_agent,
    get_memory_middleware,
    make_mem0_config,
    qdrant_backend_label,
)


def test_make_mem0_config_uses_project_embedding_dimension():
    cfg = make_mem0_config()

    assert cfg.vector_store.provider == "qdrant"
    assert cfg.vector_store.config.embedding_model_dims == 1024
    assert cfg.vector_store.config.collection_name == "dosclaw_qwen_1024"


def test_make_mem0_config_can_scope_local_qdrant_path_by_identity():
    cfg = make_mem0_config("tenant/demo", "cust:a")

    assert cfg.vector_store.config.path.endswith("/tenant_demo/cust_a")


def test_make_mem0_config_uses_qdrant_server_when_configured(monkeypatch):
    monkeypatch.setattr(agent_module.config, "MEM0_QDRANT_HOST", "127.0.0.1")
    monkeypatch.setattr(agent_module.config, "MEM0_QDRANT_PORT", 6333)

    cfg = make_mem0_config("tenant/demo", "cust:a")

    assert cfg.vector_store.config.host == "127.0.0.1"
    assert cfg.vector_store.config.port == 6333
    assert qdrant_backend_label() == "Qdrant server 127.0.0.1:6333"


def test_apply_demo_permission_rules_allows_demo_tools_only():
    state = AgentState()

    apply_demo_permission_rules(state)

    assert state.permission_context.allow_rules["knowledge_search"][0].behavior == PermissionBehavior.ALLOW
    assert state.permission_context.allow_rules["human_handoff"][0].behavior == PermissionBehavior.ALLOW


def test_get_memory_middleware_reuses_qdrant_client_per_identity(monkeypatch):
    created = []

    class FakeMiddleware:
        def __init__(self, **kwargs):
            created.append(kwargs)

    monkeypatch.setattr(agent_module, "Mem0Middleware", FakeMiddleware)
    monkeypatch.setattr(agent_module.model, "make_chat_model", lambda stream=False: f"chat:{stream}")
    monkeypatch.setattr(agent_module.model, "make_embedding_model", lambda: "embedding")
    monkeypatch.setattr(agent_module, "make_mem0_config", lambda *args: "mem0-config")
    get_memory_middleware.cache_clear()

    first = get_memory_middleware("tenant_demo", "cust_a", "both")
    second = get_memory_middleware("tenant_demo", "cust_a", "both")

    assert first is second
    assert len(created) == 1
    assert created[0]["user_id"] == "cust_a"
    assert created[0]["agent_id"] == "tenant_demo"
    assert created[0]["chat_model"] == "chat:False"
    get_memory_middleware.cache_clear()


@pytest.mark.asyncio
async def test_build_agent_exposes_agent_controlled_mem0_tools(monkeypatch):
    captured = {}

    class FakeMiddleware:
        def __init__(self, **kwargs):
            self.kwargs = kwargs

        async def list_tools(self):
            return ["search_memory", "add_memory"]

    class FakeToolkit:
        def __init__(self, tools):
            captured["toolkit_tools"] = tools

    class FakeAgent:
        def __init__(self, **kwargs):
            captured["agent_kwargs"] = kwargs

    monkeypatch.setattr(agent_module, "Mem0Middleware", FakeMiddleware)
    monkeypatch.setattr(agent_module, "Toolkit", FakeToolkit)
    monkeypatch.setattr(agent_module, "Agent", FakeAgent)
    monkeypatch.setattr(agent_module.model, "make_chat_model", lambda stream=True: f"chat:{stream}")
    monkeypatch.setattr(agent_module.model, "make_embedding_model", lambda: "embedding")
    monkeypatch.setattr(agent_module, "make_mem0_config", lambda *args: "mem0-config")
    get_memory_middleware.cache_clear()

    await build_agent("tenant_demo", "cust_a")

    assert "search_memory" in captured["toolkit_tools"]
    assert "add_memory" in captured["toolkit_tools"]
    get_memory_middleware.cache_clear()
