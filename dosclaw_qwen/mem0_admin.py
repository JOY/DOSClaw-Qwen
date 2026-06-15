"""Mem0 management helpers for the demo API and UI."""

from __future__ import annotations

from typing import Any

from . import agent as agent_module
from .store import Store


class Mem0Admin:
    """Small scoped facade over the Mem0 client used by AgentScope."""

    def __init__(self, store: Store | Any | None = None) -> None:
        self.store = store or Store()

    async def list_memories(self, tenant_id: str, customer_id: str, top_k: int = 20) -> dict[str, Any]:
        client = self._client(tenant_id, customer_id)
        raw = await client.get_all(filters=self._filters(tenant_id, customer_id), top_k=top_k)
        return {
            "profile": await self.store.get_profile(tenant_id, customer_id),
            "memories": _extract_items(raw),
        }

    async def search_memories(
        self,
        tenant_id: str,
        customer_id: str,
        query: str,
        top_k: int = 5,
    ) -> dict[str, Any]:
        client = self._client(tenant_id, customer_id)
        raw = await client.search(
            query,
            filters=self._filters(tenant_id, customer_id),
            top_k=top_k,
            rerank=False,
            explain=True,
        )
        return {"results": _extract_items(raw)}

    async def add_memory(
        self,
        tenant_id: str,
        customer_id: str,
        text: str,
        infer: bool = True,
    ) -> dict[str, Any] | None:
        middleware = self._middleware(tenant_id, customer_id)
        if infer and hasattr(middleware, "_async_add_with_fallback"):
            return await middleware._async_add_with_fallback(
                text,
                user_id=customer_id,
                agent_id=tenant_id,
            )
        return await middleware._async_add(
            [{"role": "user", "content": text, "name": "user"}],
            user_id=customer_id,
            agent_id=tenant_id,
            infer=infer,
        )

    async def update_memory(
        self,
        tenant_id: str,
        customer_id: str,
        memory_id: str,
        text: str,
    ) -> dict[str, Any] | None:
        client = self._client(tenant_id, customer_id)
        await self._require_scoped_memory(client, tenant_id, customer_id, memory_id)
        return await client.update(memory_id, text, metadata=self._filters(tenant_id, customer_id))

    async def get_memory(self, tenant_id: str, customer_id: str, memory_id: str) -> dict[str, Any]:
        client = self._client(tenant_id, customer_id)
        return await self._require_scoped_memory(client, tenant_id, customer_id, memory_id)

    async def delete_memory(
        self,
        tenant_id: str,
        customer_id: str,
        memory_id: str,
    ) -> dict[str, Any] | None:
        client = self._client(tenant_id, customer_id)
        await self._require_scoped_memory(client, tenant_id, customer_id, memory_id)
        return await client.delete(memory_id)

    async def delete_all_memories(self, tenant_id: str, customer_id: str) -> dict[str, Any]:
        client = self._client(tenant_id, customer_id)
        result = await client.delete_all(user_id=customer_id, agent_id=tenant_id)
        await self.store.set_profile(tenant_id, customer_id, {})
        if isinstance(result, dict):
            return {**result, "profile_cleared": True}
        return {"message": "Memories deleted successfully!", "profile_cleared": True}

    async def memory_history(
        self,
        tenant_id: str,
        customer_id: str,
        memory_id: str,
    ) -> list[dict[str, Any]]:
        client = self._client(tenant_id, customer_id)
        await self._require_scoped_memory(client, tenant_id, customer_id, memory_id)
        history = await client.history(memory_id)
        return _extract_items(history)

    async def _require_scoped_memory(
        self,
        client: Any,
        tenant_id: str,
        customer_id: str,
        memory_id: str,
    ) -> dict[str, Any]:
        memory = await client.get(memory_id)
        if not memory:
            raise ValueError(f"Memory {memory_id} was not found.")
        memory_user = memory.get("user_id")
        memory_agent = memory.get("agent_id")
        if memory_user and memory_user != customer_id:
            raise PermissionError("Memory does not belong to this customer.")
        if memory_agent and memory_agent != tenant_id:
            raise PermissionError("Memory does not belong to this tenant.")
        return memory

    def _middleware(self, tenant_id: str, customer_id: str) -> Any:
        return agent_module.get_memory_middleware(tenant_id, customer_id, "both")

    def _client(self, tenant_id: str, customer_id: str) -> Any:
        return self._middleware(tenant_id, customer_id)._client

    @staticmethod
    def _filters(tenant_id: str, customer_id: str) -> dict[str, str]:
        return {"user_id": customer_id, "agent_id": tenant_id}


def _extract_items(raw: Any) -> list[dict[str, Any]]:
    if raw is None:
        return []
    if isinstance(raw, dict):
        for key in ("results", "memories", "data", "history"):
            value = raw.get(key)
            if isinstance(value, list):
                return [_as_item(item) for item in value]
        return [_as_item(raw)]
    if isinstance(raw, list):
        return [_as_item(item) for item in raw]
    return [{"value": raw}]


def _as_item(item: Any) -> dict[str, Any]:
    if isinstance(item, dict):
        return item
    if hasattr(item, "model_dump"):
        return item.model_dump()
    if hasattr(item, "__dict__"):
        return dict(item.__dict__)
    return {"value": item}
