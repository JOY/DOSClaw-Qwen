"""AgentScope tool functions for shop knowledge search and human escalation."""

from __future__ import annotations

from agentscope.message import TextBlock
from agentscope.tool import ToolResponse

from . import model
from .store import Store


def _tool_text(text: str) -> ToolResponse:
    return ToolResponse(content=[TextBlock(text=text)])


def make_knowledge_search(tenant_id: str, store: Store | None = None):
    db = store or Store()

    async def knowledge_search(query: str) -> ToolResponse:
        """Search the shop FAQ, policies, menu, and service knowledge base."""
        embedding = await model.embed(query)
        hits = await db.search_knowledge(tenant_id, embedding, limit=3)
        if not hits:
            return _tool_text("No matching shop information was found.")
        text = "\n\n".join(f"{hit['title']}: {hit['content']}" for hit in hits)
        return _tool_text(text)

    return knowledge_search


def make_human_handoff(tenant_id: str, customer_id: str, store: Store | None = None):
    db = store or Store()

    async def human_handoff(reason: str) -> ToolResponse:
        """Escalate a customer issue to a human teammate when policy cannot resolve it."""
        ticket_id = await db.log_handoff(tenant_id, customer_id, reason)
        return _tool_text(
            f"Escalated to a human teammate as ticket #{ticket_id}. They will follow up.",
        )

    return human_handoff

