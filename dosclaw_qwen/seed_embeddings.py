"""Seed demo knowledge rows with DashScope embeddings."""

from __future__ import annotations

import asyncio

from . import config, model, store
from .store import Store

KNOWLEDGE_ROWS = {
    config.DEFAULT_TENANT_ID: [
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
    ],
    "tenant_skate": [
        (
            "Opening hours",
            "Deckhouse Skate Shop is open Tuesday through Sunday from 11:00 AM to 9:00 PM.",
        ),
        (
            "Deck setup help",
            "Staff can help customers choose deck width, trucks, wheels, bearings, and grip tape for street or park skating.",
        ),
        (
            "Return policy",
            "Used decks, bearings, and wheels require a human teammate to review the return before any refund is approved.",
        ),
    ],
}


async def main() -> None:
    db = Store()
    for tenant_id, rows in KNOWLEDGE_ROWS.items():
        for title, content in rows:
            embedding = await model.embed(f"{title}\n{content}")
            await db.add_knowledge(tenant_id, title, content, embedding)
    await store.close_pool()


if __name__ == "__main__":
    asyncio.run(main())
