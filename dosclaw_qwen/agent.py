"""AgentScope agent construction for DOSClaw-Qwen."""

from __future__ import annotations

from agentscope.agent import Agent, ReActConfig
from agentscope.middleware import Mem0Middleware
from agentscope.tool import FunctionTool, Toolkit

from . import model, tools
from .store import Store

SYSTEM_PROMPT = (
    "You are DOSClaw-Qwen, a multilingual customer-support agent for a small business. "
    "The public demo runs in English, but you should answer in the customer's language. "
    "Use remembered customer facts only when relevant. Use knowledge_search for product, "
    "menu, FAQ, and policy questions. Use human_handoff for refunds, complex complaints, "
    "or anything outside policy. Be concise, warm, and never invent shop facts."
)


def build_agent(
    tenant_id: str,
    customer_id: str,
    store: Store | None = None,
    mode: str = "both",
) -> Agent:
    """Build a per-tenant, per-customer AgentScope agent with mem0 memory isolation."""
    chat_model = model.make_chat_model(stream=True)
    embedding_model = model.make_embedding_model()
    db = store or Store()
    toolkit = Toolkit(
        tools=[
            FunctionTool(tools.make_knowledge_search(tenant_id, db), name="knowledge_search"),
            FunctionTool(
                tools.make_human_handoff(tenant_id, customer_id, db),
                name="human_handoff",
            ),
        ],
    )
    memory = Mem0Middleware(
        user_id=customer_id,
        agent_id=tenant_id,
        chat_model=chat_model,
        embedding_model=embedding_model,
        mode=mode,
    )
    return Agent(
        name="DOSClaw-Qwen",
        system_prompt=SYSTEM_PROMPT,
        model=chat_model,
        toolkit=toolkit,
        middlewares=[memory],
        react_config=ReActConfig(max_iters=10),
    )

