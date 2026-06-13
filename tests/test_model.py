import pytest

from agentscope.credential import DashScopeCredential

from dosclaw_qwen.model import QwenCompatibleEmbeddingModel


class FakeEmbeddings:
    def __init__(self):
        self.calls = []

    async def create(self, **kwargs):
        self.calls.append(kwargs)

        class Item:
            embedding = [0.1, 0.2, 0.3]

        class Usage:
            total_tokens = 3

        class Response:
            data = [Item()]
            usage = Usage()

        return Response()


class FakeClient:
    def __init__(self):
        self.embeddings = FakeEmbeddings()


@pytest.mark.asyncio
async def test_qwen_compatible_embedding_model_uses_openai_compatible_endpoint():
    fake_client = FakeClient()
    model = QwenCompatibleEmbeddingModel(
        credential=DashScopeCredential(api_key="test-key", base_url="https://example.test/v1"),
        model="text-embedding-v4",
        dimensions=3,
        client_factory=lambda api_key, base_url: fake_client,
    )

    response = await model(["hello"])

    assert response["embeddings"] == [[0.1, 0.2, 0.3]]
    assert fake_client.embeddings.calls == [
        {"model": "text-embedding-v4", "input": ["hello"], "dimensions": 3},
    ]
