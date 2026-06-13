from agentscope.permission import PermissionBehavior
from agentscope.state import AgentState

from dosclaw_qwen.agent import apply_demo_permission_rules, make_mem0_config


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
