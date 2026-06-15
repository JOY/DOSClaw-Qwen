"""Application service coordinating memory recall and AgentScope chat streaming."""

from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any

from agentscope.event import ReplyStartEvent, TextBlockDeltaEvent, ToolCallStartEvent
from agentscope.message import Msg, UserMsg

from . import config
from . import agent as agent_module
from . import model
from .mem0_admin import Mem0Admin
from .memory_service import MemoryService
from .store import Store


class ChatService:
    """High-level API used by FastAPI endpoints."""

    def __init__(
        self,
        store: Store | Any | None = None,
        memory_service: MemoryService | None = None,
        mem0_admin: Mem0Admin | None = None,
    ) -> None:
        self.store = store or Store()
        self.memory_service = memory_service or MemoryService(store=self.store)
        self.mem0_admin = mem0_admin or Mem0Admin(store=self.store)

    async def list_customers(self, tenant_id: str) -> list[dict[str, Any]]:
        return await self.store.list_customers(tenant_id)

    async def list_tenants(self) -> list[dict[str, Any]]:
        return await self.store.list_tenants()

    async def chat_events(
        self,
        tenant_id: str,
        customer_id: str,
        message: str,
    ) -> AsyncIterator[dict[str, str]]:
        recalled = await self.memory_service.recall(tenant_id, customer_id, message)
        consent = await self.memory_service.get_consent(tenant_id, customer_id)
        memory_writes_active = consent["status"] == "active"
        memory_mode = "both" if memory_writes_active else "agent_control"
        yield {"kind": "memory", "text": recalled}
        yield {"kind": "model_info", "text": model_info_text()}
        if not memory_writes_active:
            yield {"kind": "memory_policy", "text": "Memory writes paused for this customer."}

        agent = await agent_module.build_agent(tenant_id, customer_id, self.store, mode=memory_mode)
        reply_parts: list[str] = []
        async for event in agent.reply_stream(UserMsg(name="user", content=message)):
            if isinstance(event, ReplyStartEvent):
                mem0_text = _latest_memory_context(agent.state.context)
                if mem0_text:
                    combined = "\n\n".join(part for part in [recalled, mem0_text] if part)
                    yield {"kind": "memory", "text": combined}
            elif isinstance(event, ToolCallStartEvent):
                yield {"kind": "tool_info", "text": f"Tool: {event.tool_call_name}"}
            elif isinstance(event, TextBlockDeltaEvent):
                reply_parts.append(event.delta)
                yield {"kind": "message_delta", "text": event.delta}
            elif isinstance(event, Msg) and event.role == "assistant":
                text = event.get_text_content()
                if text and not reply_parts:
                    reply_parts.append(text)
                    yield {"kind": "message_delta", "text": text}

        reply = "".join(reply_parts)
        if reply:
            yield {"kind": "message", "text": reply}
            if not memory_writes_active:
                return
            updated_profile = await self.memory_service.record(tenant_id, customer_id, message, reply)
            if updated_profile:
                yield {
                    "kind": "memory",
                    "text": self.memory_service.format_profile(updated_profile),
                }

    async def consolidate(self, tenant_id: str, customer_id: str) -> int:
        return await self.memory_service.consolidate(tenant_id, customer_id)

    async def list_memories(self, tenant_id: str, customer_id: str, top_k: int = 20) -> dict[str, Any]:
        return await self.mem0_admin.list_memories(tenant_id, customer_id, top_k=top_k)

    async def get_memory_consent(self, tenant_id: str, customer_id: str) -> dict[str, str]:
        return await self.memory_service.get_consent(tenant_id, customer_id)

    async def set_memory_consent(self, tenant_id: str, customer_id: str, status: str) -> dict[str, str]:
        return await self.memory_service.set_consent(tenant_id, customer_id, status)

    async def search_memories(
        self,
        tenant_id: str,
        customer_id: str,
        query: str,
        top_k: int = 5,
    ) -> dict[str, Any]:
        return await self.mem0_admin.search_memories(tenant_id, customer_id, query, top_k=top_k)

    async def add_memory(
        self,
        tenant_id: str,
        customer_id: str,
        text: str,
        infer: bool = True,
    ) -> dict[str, Any] | None:
        return await self.mem0_admin.add_memory(tenant_id, customer_id, text, infer=infer)

    async def update_memory(
        self,
        tenant_id: str,
        customer_id: str,
        memory_id: str,
        text: str,
    ) -> dict[str, Any] | None:
        return await self.mem0_admin.update_memory(tenant_id, customer_id, memory_id, text)

    async def get_memory(
        self,
        tenant_id: str,
        customer_id: str,
        memory_id: str,
    ) -> dict[str, Any]:
        return await self.mem0_admin.get_memory(tenant_id, customer_id, memory_id)

    async def delete_memory(
        self,
        tenant_id: str,
        customer_id: str,
        memory_id: str,
    ) -> dict[str, Any] | None:
        return await self.mem0_admin.delete_memory(tenant_id, customer_id, memory_id)

    async def delete_all_memories(self, tenant_id: str, customer_id: str) -> dict[str, Any]:
        return await self.mem0_admin.delete_all_memories(tenant_id, customer_id)

    async def memory_history(
        self,
        tenant_id: str,
        customer_id: str,
        memory_id: str,
    ) -> list[dict[str, Any]]:
        return await self.mem0_admin.memory_history(tenant_id, customer_id, memory_id)

    async def list_knowledge(self, tenant_id: str) -> list[dict[str, Any]]:
        return await self.store.list_knowledge(tenant_id)

    async def search_knowledge(
        self,
        tenant_id: str,
        query: str,
        limit: int = 3,
    ) -> list[dict[str, Any]]:
        embedding = await model.embed(query)
        return await self.store.search_knowledge(tenant_id, embedding, limit=limit)

    async def list_handoffs(
        self,
        tenant_id: str,
        status: str | None = None,
        limit: int = 20,
    ) -> list[dict[str, Any]]:
        return await self.store.list_handoffs(tenant_id, status=status, limit=limit)

    async def update_handoff_status(self, tenant_id: str, handoff_id: int, status: str) -> dict[str, Any]:
        return await self.store.update_handoff_status(tenant_id, handoff_id, status)

    async def support_analytics(
        self,
        tenant_id: str,
        customer_id: str | None = None,
    ) -> dict[str, Any]:
        stats = await self.store.support_analytics(tenant_id)
        stats["tenant_id"] = tenant_id
        stats["customer_id"] = customer_id
        if customer_id:
            try:
                memories = await self.list_memories(tenant_id, customer_id, top_k=100)
                stats["current_customer_memories"] = len(memories.get("memories", []))
            except Exception:  # noqa: BLE001
                stats["current_customer_memories"] = None
        return stats


def _latest_memory_context(context: list[Msg]) -> str:
    for msg in reversed(context):
        if msg.name == "memory":
            return msg.get_text_content()
    return ""


def model_info_text() -> str:
    return (
        f"Qwen Cloud: {config.QWEN_CHAT_MODEL} | "
        f"Embeddings: {config.QWEN_EMBED_MODEL} ({config.EMBED_DIM}d) | "
        f"AgentScope 2.0 + Mem0 | {agent_module.qdrant_backend_label()} | "
        "Memory scoped by customer and tenant"
    )
