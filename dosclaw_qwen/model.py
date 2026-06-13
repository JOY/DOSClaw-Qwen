"""Qwen Cloud wiring through AgentScope DashScope model and embedding classes."""

from __future__ import annotations

from agentscope.credential import DashScopeCredential
from agentscope.embedding import DashScopeEmbeddingModel
from agentscope.formatter import DashScopeChatFormatter
from agentscope.model import DashScopeChatModel

from . import config


def _credential() -> DashScopeCredential:
    if not config.DASHSCOPE_API_KEY:
        raise RuntimeError("DASHSCOPE_API_KEY is required for live Qwen Cloud calls.")
    return DashScopeCredential(
        api_key=config.DASHSCOPE_API_KEY,
        base_url=config.DASHSCOPE_BASE_URL,
    )


def make_chat_model(stream: bool = True) -> DashScopeChatModel:
    """Create the AgentScope chat model backed by Qwen Cloud."""
    return DashScopeChatModel(
        credential=_credential(),
        model=config.QWEN_CHAT_MODEL,
        stream=stream,
        formatter=DashScopeChatFormatter(),
    )


def make_embedding_model() -> DashScopeEmbeddingModel:
    """Create the AgentScope embedding model backed by DashScope."""
    return DashScopeEmbeddingModel(
        credential=_credential(),
        model=config.QWEN_EMBED_MODEL,
    )


async def embed(text: str, embedding_model: DashScopeEmbeddingModel | None = None) -> list[float]:
    """Embed one text and return the first vector."""
    model = embedding_model or make_embedding_model()
    response = await model([text])
    return response["embeddings"][0]

