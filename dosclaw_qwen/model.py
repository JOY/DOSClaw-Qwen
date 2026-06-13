"""Qwen Cloud wiring through AgentScope and OpenAI-compatible DashScope APIs."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Callable

from openai import APIConnectionError, APITimeoutError, AsyncOpenAI, RateLimitError
from agentscope.credential import DashScopeCredential
from agentscope.embedding import EmbeddingModelBase, EmbeddingResponse, EmbeddingUsage
from agentscope.formatter import DashScopeChatFormatter
from agentscope.model import DashScopeChatModel
from pydantic import BaseModel, Field

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


class QwenCompatibleEmbeddingModel(EmbeddingModelBase[str]):
    """AgentScope embedding model that uses DashScope's OpenAI-compatible endpoint."""

    class Parameters(BaseModel):
        dimensions: int = Field(default=1024, gt=0)

    def __init__(
        self,
        credential: DashScopeCredential,
        model: str,
        dimensions: int = 1024,
        context_size: int = 8192,
        batch_size: int = 10,
        max_retries: int = 3,
        retry_delay: float = 1.0,
        client_factory: Callable[[str, str], Any] | None = None,
    ) -> None:
        super().__init__(
            credential=credential,
            model=model,
            parameters=self.Parameters(dimensions=dimensions),
            context_size=context_size,
            batch_size=batch_size,
            max_retries=max_retries,
            retry_delay=retry_delay,
        )
        self.client_factory = client_factory or (
            lambda api_key, base_url: AsyncOpenAI(api_key=api_key, base_url=base_url)
        )

    @classmethod
    def _get_retryable_exceptions(cls) -> tuple[type[Exception], ...]:
        return (APIConnectionError, APITimeoutError, RateLimitError)

    async def _call_api(self, inputs: list[str], **kwargs: Any) -> EmbeddingResponse:
        client = self.client_factory(
            self.credential.api_key.get_secret_value(),
            self.credential.base_url,
        )
        started = datetime.now()
        response = await client.embeddings.create(
            model=self.model,
            input=inputs,
            dimensions=self.dimensions,
            **kwargs,
        )
        elapsed = (datetime.now() - started).total_seconds()
        total_tokens = _usage_total_tokens(getattr(response, "usage", None))
        return EmbeddingResponse(
            embeddings=[item.embedding for item in response.data],
            usage=EmbeddingUsage(tokens=total_tokens, time=elapsed),
        )


def _usage_total_tokens(usage: Any) -> int:
    if usage is None:
        return 0
    if isinstance(usage, dict):
        return int(usage.get("total_tokens", 0))
    return int(getattr(usage, "total_tokens", 0) or 0)


def make_embedding_model() -> QwenCompatibleEmbeddingModel:
    """Create an AgentScope-compatible embedding model backed by Qwen Cloud."""
    return QwenCompatibleEmbeddingModel(
        credential=_credential(),
        model=config.QWEN_EMBED_MODEL,
        dimensions=config.EMBED_DIM,
    )


async def embed(text: str, embedding_model: DashScopeEmbeddingModel | None = None) -> list[float]:
    """Embed one text and return the first vector."""
    model = embedding_model or make_embedding_model()
    response = await model([text])
    return response["embeddings"][0]
