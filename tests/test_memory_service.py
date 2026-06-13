import pytest

from dosclaw_qwen.memory_service import MemoryService


class FakeStore:
    def __init__(self):
        self.profile = {
            "name": "Linh",
            "lactose_intolerant": True,
            "prefers": "oat milk",
        }
        self.episodes = [
            {
                "id": 1,
                "summary": "Linh enjoyed an oat latte last time.",
                "similarity": 0.9,
                "age_days": 2,
                "importance": 0.8,
            },
            {
                "id": 2,
                "summary": "A stale low-value note.",
                "similarity": 0.1,
                "age_days": 80,
                "importance": 0.1,
            },
        ]

    async def get_profile(self, tenant_id, customer_id):
        return self.profile

    async def set_profile(self, tenant_id, customer_id, facts):
        self.profile = facts

    async def search_memories(self, tenant_id, customer_id, query, limit=20):
        return self.episodes


@pytest.mark.asyncio
async def test_recall_combines_profile_and_ranked_memories():
    service = MemoryService(store=FakeStore(), mem0_factory=None)

    recalled = await service.recall(
        tenant_id="tenant_demo",
        customer_id="cust_a",
        query="What do you recommend?",
    )

    assert "Customer profile" in recalled
    assert "lactose_intolerant" in recalled
    assert "Relevant memories" in recalled
    assert "oat latte" in recalled
    assert "stale low-value" not in recalled


@pytest.mark.asyncio
async def test_record_merges_extracted_profile_facts():
    store = FakeStore()

    async def extractor(user_text, assistant_text):
        return {"profile": {"lactose_intolerant": True, "prefers": "oat milk"}}

    service = MemoryService(store=store, mem0_factory=None, extractor=extractor)

    await service.record(
        tenant_id="tenant_demo",
        customer_id="cust_b",
        user_text="I'm lactose intolerant.",
        assistant_text="Oat milk is available.",
    )

    assert store.profile["lactose_intolerant"] is True
    assert store.profile["prefers"] == "oat milk"
