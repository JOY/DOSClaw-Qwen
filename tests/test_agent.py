from agentscope.permission import PermissionBehavior
from agentscope.state import AgentState

from dosclaw_qwen import agent as agent_module
from dosclaw_qwen.agent import apply_demo_permission_rules, get_memory_middleware, make_mem0_config


def test_make_mem0_config_uses_project_embedding_dimension():
    cfg = make_mem0_config()

    assert cfg.vector_store.provider == "qdrant"
    assert cfg.vector_store.config.embedding_model_dims == 1024
    assert cfg.vector_store.config.collection_name == "dosclaw_qwen_1024"


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
    monkeypatch.setattr(agent_module, "make_mem0_config", lambda: "mem0-config")
    get_memory_middleware.cache_clear()

    first = get_memory_middleware("tenant_demo", "cust_a", "both")
    second = get_memory_middleware("tenant_demo", "cust_a", "both")

    assert first is second
    assert len(created) == 1
    assert created[0]["user_id"] == "cust_a"
    assert created[0]["agent_id"] == "tenant_demo"
    assert created[0]["chat_model"] == "chat:False"
    get_memory_middleware.cache_clear()
