"""Seed demo knowledge rows with DashScope embeddings."""

from __future__ import annotations

import asyncio

from . import config, model, store
from .store import Store

KNOWLEDGE_ROWS = [
    (
        "Opening hours",
        "Bloom Cafe is open Monday through Saturday from 8:00 AM to 8:00 PM.",
    ),
    (
        "Dairy-free options",
        "Oat milk and soy milk are available for all espresso drinks at no extra charge.",
    ),
    (
        "Refund policy",
        "Refunds for incorrect or damaged orders require a human teammate to review the case.",
    ),
]


async def main() -> None:
    db = Store()
    for title, content in KNOWLEDGE_ROWS:
        embedding = await model.embed(f"{title}\n{content}")
        await db.add_knowledge(config.DEFAULT_TENANT_ID, title, content, embedding)
    await store.close_pool()


if __name__ == "__main__":
    asyncio.run(main())

