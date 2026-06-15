"""AgentScope agent construction for DOSClaw-Qwen."""

from __future__ import annotations

from functools import lru_cache

from agentscope.agent import Agent, ReActConfig
from agentscope.middleware import Mem0Middleware
from agentscope.permission import PermissionBehavior, PermissionRule
from agentscope.state import AgentState
from agentscope.tool import FunctionTool, Toolkit

from . import config
from . import model, tools
from .store import Store

SYSTEM_PROMPT = (
    "You are DOSClaw-Qwen, a multilingual customer-support agent for a small business. "
    "The public demo runs in English, but you should answer in the customer's language. "
    "Use remembered customer facts only when relevant. Use knowledge_search for product, "
    "menu, FAQ, and policy questions. Use human_handoff for refunds, complex complaints, "
    "or anything outside policy. Be concise, warm, and never invent shop facts."
)


async def build_agent(
    tenant_id: str,
    customer_id: str,
    store: Store | None = None,
    mode: str = "both",
) -> Agent:
    """Build a per-tenant, per-customer AgentScope agent with mem0 memory isolation."""
    chat_model = model.make_chat_model(stream=True)
    db = store or Store()
    memory = get_memory_middleware(tenant_id, customer_id, mode)
    memory_tools = await memory.list_tools()
    toolkit = Toolkit(
        tools=[
            FunctionTool(tools.make_knowledge_search(tenant_id, db), name="knowledge_search"),
            FunctionTool(
                tools.make_human_handoff(tenant_id, customer_id, db),
                name="human_handoff",
            ),
            *memory_tools,
        ],
    )
    state = AgentState()
    apply_demo_permission_rules(state)
    return Agent(
        name="DOSClaw-Qwen",
        system_prompt=SYSTEM_PROMPT,
        model=chat_model,
        toolkit=toolkit,
        middlewares=[memory],
        state=state,
        react_config=ReActConfig(max_iters=10),
    )


@lru_cache(maxsize=256)
def get_memory_middleware(tenant_id: str, customer_id: str, mode: str) -> Mem0Middleware:
    """Reuse mem0/Qdrant clients so local Qdrant storage is opened once per identity."""
    return Mem0Middleware(
        user_id=customer_id,
        agent_id=tenant_id,
        chat_model=model.make_chat_model(stream=False),
        embedding_model=model.make_embedding_model(),
        mem0_config=make_mem0_config(tenant_id, customer_id),
        mode=mode,
    )


def make_mem0_config(tenant_id: str | None = None, customer_id: str | None = None):
    """Build mem0 config with vector dimensions matching Qwen embeddings."""
    from mem0.configs.base import MemoryConfig
    from mem0.vector_stores.configs import VectorStoreConfig

    qdrant_config: dict[str, object] = {
        "collection_name": f"dosclaw_qwen_{config.EMBED_DIM}",
        "embedding_model_dims": config.EMBED_DIM,
    }
    if config.MEM0_QDRANT_HOST and config.MEM0_QDRANT_PORT:
        qdrant_config.update(
            {
                "host": config.MEM0_QDRANT_HOST,
                "port": config.MEM0_QDRANT_PORT,
            },
        )
    else:
        path = config.MEM0_QDRANT_PATH
        if tenant_id and customer_id:
            path = f"{path}/{_path_segment(tenant_id)}/{_path_segment(customer_id)}"
        qdrant_config["path"] = path

    return MemoryConfig(
        vector_store=VectorStoreConfig(
            provider="qdrant",
            config=qdrant_config,
        ),
    )


def qdrant_backend_label() -> str:
    """Return a non-secret label for the active mem0 vector store backend."""
    if config.MEM0_QDRANT_HOST and config.MEM0_QDRANT_PORT:
        return f"Qdrant server {config.MEM0_QDRANT_HOST}:{config.MEM0_QDRANT_PORT}"
    return "Qdrant local path"


def _path_segment(value: str) -> str:
    return "".join(ch if ch.isalnum() or ch in ("-", "_") else "_" for ch in value)


def apply_demo_permission_rules(state: AgentState) -> None:
    """Allow the two built-in demo tools to run inside the web backend."""
    for tool_name in ("knowledge_search", "human_handoff"):
        state.permission_context.allow_rules[tool_name] = [
            PermissionRule(
                tool_name=tool_name,
                rule_content=None,
                behavior=PermissionBehavior.ALLOW,
                source="dosclaw-qwen-demo",
            ),
        ]
