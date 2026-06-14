"""Application service coordinating memory recall and AgentScope chat streaming."""

from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any

from agentscope.event import ReplyStartEvent, TextBlockDeltaEvent
from agentscope.message import Msg, UserMsg

from . import config
from . import agent as agent_module
from .memory_service import MemoryService
from .store import Store


class ChatService:
    """High-level API used by FastAPI endpoints."""

    def __init__(
        self,
        store: Store | Any | None = None,
        memory_service: MemoryService | None = None,
    ) -> None:
        self.store = store or Store()
        self.memory_service = memory_service or MemoryService(store=self.store)

    async def list_customers(self, tenant_id: str) -> list[dict[str, Any]]:
        return await self.store.list_customers(tenant_id)

    async def chat_events(
        self,
        tenant_id: str,
        customer_id: str,
        message: str,
    ) -> AsyncIterator[dict[str, str]]:
        recalled = await self.memory_service.recall(tenant_id, customer_id, message)
        yield {"kind": "memory", "text": recalled}
        yield {"kind": "model_info", "text": model_info_text()}

        agent = agent_module.build_agent(tenant_id, customer_id, self.store)
        reply_parts: list[str] = []
        async for event in agent.reply_stream(UserMsg(name="user", content=message)):
            if isinstance(event, ReplyStartEvent):
                mem0_text = _latest_memory_context(agent.state.context)
                if mem0_text:
                    combined = "\n\n".join(part for part in [recalled, mem0_text] if part)
                    yield {"kind": "memory", "text": combined}
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
            updated_profile = await self.memory_service.record(tenant_id, customer_id, message, reply)
            if updated_profile:
                yield {
                    "kind": "memory",
                    "text": self.memory_service.format_profile(updated_profile),
                }

    async def consolidate(self, tenant_id: str, customer_id: str) -> int:
        return await self.memory_service.consolidate(tenant_id, customer_id)


def _latest_memory_context(context: list[Msg]) -> str:
    for msg in reversed(context):
        if msg.name == "memory":
            return msg.get_text_content()
    return ""


def model_info_text() -> str:
    return (
        f"Qwen Cloud: {config.QWEN_CHAT_MODEL} | "
        f"Embeddings: {config.QWEN_EMBED_MODEL} ({config.EMBED_DIM}d) | "
        "AgentScope 2.0 + Mem0 | Memory scoped by customer and tenant"
    )
