"""Custom structured memory layer shown in the UI alongside Mem0Middleware."""

from __future__ import annotations

import json
from typing import Any, Awaitable, Callable

from openai import AsyncOpenAI

from . import config
from .ranking import merge_profile, rank_episodes
from .store import Store

Mem0Factory = Callable[..., Any]
Extractor = Callable[[str, str], Awaitable[dict[str, Any]]]
MEMORY_CONSENT_KEY = "memory_consent"
ACTIVE_MEMORY_CONSENT = "active"
PAUSED_MEMORY_CONSENT = "paused"
VALID_MEMORY_CONSENT = {ACTIVE_MEMORY_CONSENT, PAUSED_MEMORY_CONSENT}

_EXTRACT_SYSTEM = (
    "Extract durable customer profile facts from one support turn. "
    "Return strict JSON only: {\"profile\": {...}}. "
    "Use concise snake_case keys such as name, age, preferred_drink, lactose_intolerant, "
    "preferred_milk, last_order, complaint_status. If the customer states their name or "
    "age directly, include it. Include only stable facts worth remembering for future "
    "support. Use null to forget a fact when the customer corrects it."
)


class MemoryService:
    """Profile-first memory composer with optional mem0-backed episodic search."""

    def __init__(
        self,
        store: Store | Any | None = None,
        mem0_factory: Mem0Factory | None = None,
        extractor: Extractor | None = None,
    ) -> None:
        self.store = store or Store()
        self.mem0_factory = mem0_factory
        self.extractor = extractor or extract_profile_facts

    async def recall(self, tenant_id: str, customer_id: str, query: str) -> str:
        """Return the compact memory block displayed and injected for a turn."""
        profile = await self.store.get_profile(tenant_id, customer_id)
        episodes = await self.store.search_memories(tenant_id, customer_id, query, limit=20)
        ranked = rank_episodes(episodes, k=5) if episodes else []

        lines: list[str] = []
        if profile:
            lines.append(self.format_profile(profile))
        if ranked:
            lines.append("Relevant memories:")
            lines.extend(f"- {episode['summary']}" for episode in ranked)
        return "\n".join(lines)

    async def merge_profile(
        self,
        tenant_id: str,
        customer_id: str,
        facts: dict[str, Any],
    ) -> dict[str, Any]:
        """Merge new durable facts into the structured profile."""
        current = await self.store.get_profile(tenant_id, customer_id)
        merged = merge_profile(current, facts)
        await self.store.set_profile(tenant_id, customer_id, merged)
        return merged

    async def get_consent(self, tenant_id: str, customer_id: str) -> dict[str, str]:
        """Return the customer-facing memory consent state."""
        profile = await self.store.get_profile(tenant_id, customer_id)
        status = _normalize_consent(profile.get(MEMORY_CONSENT_KEY))
        return {"customer_id": customer_id, "status": status}

    async def set_consent(self, tenant_id: str, customer_id: str, status: str) -> dict[str, str]:
        """Persist whether automatic profile memory writes are active or paused."""
        normalized = _normalize_consent(status)
        if normalized not in VALID_MEMORY_CONSENT:
            raise ValueError(f"Unsupported memory consent status: {status}")
        await self.merge_profile(tenant_id, customer_id, {MEMORY_CONSENT_KEY: normalized})
        return {"customer_id": customer_id, "status": normalized}

    async def can_record_profile(self, tenant_id: str, customer_id: str) -> bool:
        """Return whether automatic structured profile writes are allowed."""
        consent = await self.get_consent(tenant_id, customer_id)
        return consent["status"] == ACTIVE_MEMORY_CONSENT

    async def record(
        self,
        tenant_id: str,
        customer_id: str,
        user_text: str,
        assistant_text: str,
    ) -> dict[str, Any] | None:
        """Extract durable structured facts from a turn and merge them into the profile."""
        extracted = await self.extractor(user_text, assistant_text)
        facts = extracted.get("profile") or {}
        if facts:
            return await self.merge_profile(tenant_id, customer_id, facts)
        return None

    async def consolidate(self, tenant_id: str, customer_id: str, floor: float = 0.1) -> int:
        """Consolidate stale custom memories; mem0 currently owns episodic storage."""
        return 0

    @staticmethod
    def format_profile(profile: dict[str, Any]) -> str:
        """Format structured profile facts for the judge-facing memory panel."""
        if not profile:
            return ""
        lines = ["Customer profile:"]
        preferred_order = ["name", "age"]
        ordered_keys = [
            *[key for key in preferred_order if key in profile],
            *sorted(key for key in profile if key not in preferred_order),
        ]
        for key in ordered_keys:
            value = profile[key]
            label = key.replace("_", " ").capitalize()
            lines.append(f"- {label}: {value}")
        return "\n".join(lines)


async def extract_profile_facts(user_text: str, assistant_text: str) -> dict[str, Any]:
    """Use Qwen Cloud to extract durable structured profile facts."""
    if not config.DASHSCOPE_API_KEY:
        return {"profile": {}}

    client = AsyncOpenAI(
        api_key=config.DASHSCOPE_API_KEY,
        base_url=config.DASHSCOPE_BASE_URL,
    )
    response = await client.chat.completions.create(
        model=config.QWEN_CHAT_MODEL,
        messages=[
            {"role": "system", "content": _EXTRACT_SYSTEM},
            {
                "role": "user",
                "content": (
                    "Customer said:\n"
                    f"{user_text}\n\n"
                    "Assistant replied:\n"
                    f"{assistant_text}"
                ),
            },
        ],
        response_format={"type": "json_object"},
    )
    content = response.choices[0].message.content or "{}"
    try:
        parsed = json.loads(content)
    except json.JSONDecodeError:
        return {"profile": {}}
    if not isinstance(parsed, dict):
        return {"profile": {}}
    profile = parsed.get("profile")
    return {"profile": profile if isinstance(profile, dict) else {}}


def _normalize_consent(value: Any) -> str:
    if value is None or value == "":
        return ACTIVE_MEMORY_CONSENT
    status = str(value).strip().lower()
    return status if status in VALID_MEMORY_CONSENT else status
