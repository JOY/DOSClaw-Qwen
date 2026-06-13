# AgentScope 2.0.1 - Verified API Reference (READ BEFORE CODING)

> This file records the **actual** AgentScope 2.0.1 API, verified by introspecting the
> installed package on 2026-06-13 (Python 3.14, Windows). `docs/implementation-plan.md` was
> written *before* this verification and contains several **wrong** AgentScope symbols
> (`ReActAgent`, `agentscope.memory.LongTermMemoryBase`, `toolkit.register_tool_function`,
> `DashScopeChatModel(api_key=...)`). **Where the plan and this file disagree, THIS FILE WINS.**
> The plan's *memory engine design* (profile + episodic pgvector + recall ranking + forgetting)
> and *task breakdown* are still correct - only the AgentScope wiring layer changed.

## MEMORY UPDATE 2026-06-13 (supersedes §5 below)

AgentScope 2.0 adds long-term memory via a **middleware** (the installed 2.0.1 has a confirmed
`agentscope.middleware` module; there is NO `agentscope.memory`). Use the **`Mem0Middleware`** from
upstream **PR #1775** (mem0-backed; routes mem0 through our DashScope/Qwen model via
`build_mem0_config` - no OpenAI key). See `MEMORY_STACK.md`. Sections §1-§4 below (verified 2.0 API:
`Agent`, `DashScopeChatModel`, `FunctionTool`, `ToolResponse`, `reply`/`observe`) remain correct;
**§5 (hand-rolled memory service) is SUPERSEDED by the middleware.**

> DashScope international routing: AgentScope 1.0's chat model used
> `base_http_api_url="https://dashscope-intl.aliyuncs.com/api/v1"` (native SDK), and that global
> also routed embeddings. 2.0's `DashScopeChatModel` takes a `credential=` object instead - confirm
> where the int'l base URL goes in 2.0 (credential / client_kwargs) when wiring DashScope.

## 0. Environment (verified)

- Python **3.14.0** works. All deps install with cp314/pure-python wheels. Pinned/observed versions:
  `agentscope==2.0.1`, `openai==2.41.1`, `asyncpg==0.31.0`, `fastapi==0.136.3`,
  `uvicorn==0.49.0`, `python-dotenv==1.2.2`, `pytest==9.0.3`, `pytest-asyncio==1.4.0`,
  `pydantic-core==2.46.4`.
- Production runtime stays Docker `python:3.11-slim` (Dockerfile). 3.14 is fine for local dev too.

## 1. What actually exists in `agentscope` 2.0.1

```
agentscope            -> logger, setup_logger, warnings           (NO top-level Agent/Msg)
agentscope.agent      -> Agent, ContextConfig, ModelConfig, ReActConfig   (NO ReActAgent)
agentscope.model      -> DashScopeChatModel, OpenAIChatModel, ChatModelBase, ... (+ Anthropic/Gemini/...)
agentscope.formatter  -> DashScopeChatFormatter, FormatterBase, ...
agentscope.credential -> DashScopeCredential, CredentialBase, CredentialFactory, ...
agentscope.tool       -> Toolkit, FunctionTool, ToolResponse, ToolBase, MCPTool, RegisteredTool, ...
                         (NO register_tool_function; Function is a typing.Union alias, NOT a decorator)
agentscope.message    -> Msg, UserMsg, AssistantMsg, SystemMsg, TextBlock, ToolCallBlock, ...
agentscope.embedding  -> DashScopeTextEmbedding, EmbeddingModelBase, EmbeddingResponse, FileEmbeddingCache, ...
agentscope.mcp        -> MCPClient, HttpMCPConfig, StdioMCPConfig   (NOT HttpStatefulClient/HttpStatelessClient)
agentscope.memory     -> DOES NOT EXIST. There is no LongTermMemoryBase / InMemoryMemory.
                         The Agent class has NO `memory=` parameter. See section 5 for the memory approach.
```

## 2. Verified signatures

```python
# agentscope.agent.Agent.__init__
Agent(
    name: str,
    system_prompt: str,                       # NOTE: system_prompt, NOT sys_prompt
    model: ChatModelBase,
    toolkit: Toolkit | None = None,
    middlewares: list | None = None,
    state: AgentState | None = None,
    offloader: Offloader | None = None,
    model_config: ModelConfig = ModelConfig(max_retries=0, fallback_model=None),
    context_config: ContextConfig = ContextConfig(trigger_ratio=0.8, reserve_ratio=0.1, ...),
    react_config: ReActConfig = ReActConfig(max_iters=20, stop_on_reject=False),
)
# methods: await agent.reply(inputs) -> Msg   (async)
#          agent.reply_stream(inputs) -> AsyncGenerator[<rich events>]   (NOT a coroutine; async-iterate it)
#          await agent.observe(msgs) -> None   (async; inject context/messages without generating)
#          await agent.compress_context()

# agentscope.model.DashScopeChatModel.__init__
DashScopeChatModel(
    credential: DashScopeCredential,          # NOTE: credential object, NOT api_key=
    model: str,                               # NOTE: model, NOT model_name
    parameters=None,
    stream: bool = True,
    max_retries: int = 3,
    retry_delay: float = 1.0,
    context_size: int = 131072,
    formatter: FormatterBase | None = None,   # NOTE: formatter is passed to the MODEL, not the Agent
    client_kwargs: dict | None = None,
)
# classmethods/methods: DashScopeChatModel.list_models(), .count_tokens(), .generate_structured_output()

# agentscope.tool.FunctionTool.__init__
FunctionTool(
    func: Callable[..., ToolResponse | Awaitable[ToolResponse] | (Async)Generator[ToolChunk]],
    name: str | None = None,                  # defaults from func.__name__
    description: str | None = None,           # defaults from func docstring
    is_concurrency_safe: bool = True,
    is_read_only: bool = False,
    is_state_injected: bool = False,
)
# Toolkit(tools=[FunctionTool(...), ...], mcps=[MCPClient(...)], ...)
# Toolkit methods: call_tool, check_tool_available, clear, get_tool, get_tool_schemas

# agentscope.embedding.DashScopeTextEmbedding
DashScopeTextEmbedding(api_key: str, model_name: str, dimensions: int = 1024, embedding_cache=None)
# await embedder([text]) -> EmbeddingResponse   (input is a LIST of str/TextBlock; async)
```

## 3. Correct agent wiring (use this, not the plan's `ReActAgent`)

```python
import os
from agentscope.agent import Agent, ReActConfig
from agentscope.model import DashScopeChatModel
from agentscope.formatter import DashScopeChatFormatter
from agentscope.credential import DashScopeCredential
from agentscope.tool import Toolkit, FunctionTool, ToolResponse
from agentscope.message import Msg

def make_model() -> DashScopeChatModel:
    return DashScopeChatModel(
        credential=DashScopeCredential(api_key=os.environ["DASHSCOPE_API_KEY"]),  # CONFIRM field name
        model=os.environ.get("QWEN_CHAT_MODEL", "qwen3.6-plus"),                  # CONFIRM live id
        stream=True,
        formatter=DashScopeChatFormatter(),
    )

def build_agent(toolkit: Toolkit, system_prompt: str) -> Agent:
    return Agent(
        name="DOSClaw-Qwen",
        system_prompt=system_prompt,
        model=make_model(),
        toolkit=toolkit,
        react_config=ReActConfig(max_iters=10),
    )

# Per turn (customer-aware): recall -> inject -> reply -> record
async def handle_turn(customer_id: str, text: str, memory_service, toolkit, system_prompt) -> str:
    recall_block = await memory_service.recall(customer_id, text)        # OUR engine (pgvector)
    agent = build_agent(toolkit, system_prompt)
    if recall_block:
        await agent.observe(Msg(name="memory", content=recall_block, role="system"))  # CONFIRM role
    reply: Msg = await agent.reply(Msg(name="user", content=text, role="user"))
    await memory_service.record(customer_id, text, reply.get_text_content())
    return reply.get_text_content()
```

## 4. Tools must return `ToolResponse`

`FunctionTool` wraps a callable whose return type is `ToolResponse` (or yields `ToolChunk`).
A plain `-> str` (as in the plan) will NOT satisfy the type. Expected pattern (CONFIRM exact ctor):

```python
from agentscope.tool import ToolResponse
from agentscope.message import TextBlock

async def knowledge_search(query: str) -> ToolResponse:
    """Search the shop FAQ/policy/menu knowledge base. Args: query: what the customer asks."""
    hits = await store.search_knowledge(await embed(query), limit=3)
    text = "\n\n".join(f"{h['title']}: {h['content']}" for h in hits) or "No matching shop info."
    return ToolResponse(content=[TextBlock(type="text", text=text)])
```

## 5. Memory architecture in 2.0 (no `agentscope.memory`)

The plan's "subclass `LongTermMemoryBase`" is impossible (module absent; Agent has no memory hook).
Implement memory as **our own service**, surfaced two ways:

1. **Injected recall (static control):** before `agent.reply(...)`, build a compact memory block
   (`profile` + top-K episodic via `ranking.rank_episodes`) and `await agent.observe(Msg(... role="system"))`.
   This guarantees the recalled memory is in context every turn. (Used in section 3.)
2. **Agentic recall (tool, optional):** also register a `search_memory(query)` `FunctionTool` so the
   model can pull more memory mid-reasoning when it wants. Scores Innovation points (agent-controlled memory).

So the plan's `dosclaw_qwen/memory.py` becomes a plain `MemoryService` class (NOT a LongTermMemoryBase subclass):
- `async recall(customer_id, query) -> str`     # profile + ranked episodic, compact block
- `async record(customer_id, user_text, assistant_text) -> None`   # LLM-extract durable facts + episode, embed, store
- `async consolidate(customer_id, floor=0.1) -> int`   # forgetting (decay below floor)
`ranking.py` (pure: `decay_score`, `rank_episodes`, `merge_profile`) and `store.py` (asyncpg + pgvector)
are exactly as the plan describes. Embeddings use `DashScopeTextEmbedding` (section 2) instead of the
plan's raw `AsyncOpenAI` (both work; the native one is more idiomatic = Innovation).

## 6. Confirm-by-introspection checklist (do these first, they are cheap)

Run against the installed package to lock the last details before writing code:
- `DashScopeCredential` field name: `python -c "import agentscope.credential as c; print(c.DashScopeCredential.model_fields)"` (expect `api_key`).
- `ToolResponse` constructor: `python -c "import inspect,agentscope.tool as t; print(t.ToolResponse.model_fields)"` - confirm `content` shape and whether a bare string is accepted.
- `EmbeddingResponse` attribute holding vectors: `python -c "import agentscope.embedding as e; print(e.EmbeddingResponse.model_fields)"` (expect `embeddings`).
- Allowed `Msg` roles for `observe()` injection (system/user/assistant): check `Msg.validate_role_content`.
- Live Qwen chat model id: `DashScopeChatModel.list_models(...)` or Qwen Cloud model-selection doc. Candidates: `qwen3.6-plus`, `qwen-plus`, `qwen3.7-plus` (old TS used `qwen3.7-plus`). Pick the current recommended one and set `QWEN_CHAT_MODEL`.
- For SSE streaming UI: iterate `agent.reply_stream(msg)` and forward `TextBlockDeltaEvent` text; inspect event classes in `agentscope.event`.
