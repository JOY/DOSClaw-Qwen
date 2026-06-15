"""FastAPI application for the DOSClaw-Qwen demo."""

from __future__ import annotations

import json
import secrets
from pathlib import Path
from typing import Any, Literal

from fastapi import Cookie, FastAPI, HTTPException, Request, Response
from fastapi.responses import FileResponse, HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import config
from . import agent as agent_module
from .chat_service import ChatService


class ChatRequest(BaseModel):
    customer_id: str = Field(min_length=1)
    message: str = Field(min_length=1)
    tenant_id: str = config.DEFAULT_TENANT_ID


class ConsolidateRequest(BaseModel):
    customer_id: str = Field(min_length=1)
    tenant_id: str = config.DEFAULT_TENANT_ID


class MemoryAddRequest(BaseModel):
    customer_id: str = Field(min_length=1)
    text: str = Field(min_length=1)
    tenant_id: str = config.DEFAULT_TENANT_ID
    infer: bool = True


class MemoryUpdateRequest(BaseModel):
    customer_id: str = Field(min_length=1)
    text: str = Field(min_length=1)
    tenant_id: str = config.DEFAULT_TENANT_ID


class MemoryConsentRequest(BaseModel):
    customer_id: str = Field(min_length=1)
    status: Literal["active", "paused"]
    tenant_id: str = config.DEFAULT_TENANT_ID


class HandoffStatusRequest(BaseModel):
    status: Literal["open", "reviewing", "resolved"]
    tenant_id: str = config.DEFAULT_TENANT_ID


def _authorized(session: str | None) -> bool:
    if not config.DEMO_LOGIN_PASS:
        return True
    return secrets.compare_digest(session or "", "ok")


def create_app(
    chat_service: Any | None = None,
    require_login: bool | None = None,
) -> FastAPI:
    service = chat_service or ChatService()
    login_required = config.DEMO_LOGIN_PASS != "" if require_login is None else require_login
    app = FastAPI(title="DOSClaw-Qwen")
    web_dir = Path(__file__).resolve().parent.parent / "web"
    app.mount("/static", StaticFiles(directory=web_dir), name="static")

    async def guard(session: str | None) -> None:
        if login_required and not _authorized(session):
            raise HTTPException(status_code=401, detail="Login required")

    @app.get("/", response_class=HTMLResponse)
    async def index(session: str | None = Cookie(default=None)):
        if login_required and not _authorized(session):
            return HTMLResponse(
                """
                <form method="post" action="/login">
                  <input name="username" value="judge" />
                  <input name="password" type="password" />
                  <button>Sign in</button>
                </form>
                """,
            )
        return FileResponse(web_dir / "index.html")

    @app.post("/login")
    async def login(request: Request):
        form = await request.form()
        ok_user = form.get("username") == config.DEMO_LOGIN_USER
        ok_pass = form.get("password") == config.DEMO_LOGIN_PASS
        if not ok_user or not ok_pass:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        response = Response(status_code=303, headers={"Location": "/"})
        response.set_cookie("session", "ok", httponly=True, samesite="lax")
        return response

    @app.get("/api/customers")
    async def customers(
        tenant_id: str = config.DEFAULT_TENANT_ID,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.list_customers(tenant_id)

    @app.get("/api/tenants")
    async def tenants(session: str | None = Cookie(default=None)):
        await guard(session)
        return await service.list_tenants()

    @app.get("/api/health")
    async def health():
        return {"ok": True, "service": "dosclaw-qwen"}

    @app.get("/api/runtime")
    async def runtime(session: str | None = Cookie(default=None)):
        await guard(session)
        return {
            "service": "dosclaw-qwen",
            "git_sha": config.APP_GIT_SHA,
            "chat_model": config.QWEN_CHAT_MODEL,
            "embedding_model": config.QWEN_EMBED_MODEL,
            "embedding_dimensions": config.EMBED_DIM,
            "agent_runtime": "AgentScope 2.0",
            "memory_engine": "Mem0Middleware",
            "vector_store": agent_module.qdrant_backend_label(),
            "memory_scope": "tenant_id + customer_id",
        }

    @app.post("/api/chat")
    async def chat(
        request: ChatRequest,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)

        async def stream():
            async for event in service.chat_events(
                request.tenant_id,
                request.customer_id,
                request.message,
            ):
                yield json.dumps(event) + "\n"

        return StreamingResponse(stream(), media_type="application/x-ndjson")

    @app.get("/api/memory")
    async def list_memory(
        customer_id: str,
        tenant_id: str = config.DEFAULT_TENANT_ID,
        top_k: int = 20,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.list_memories(tenant_id, customer_id, top_k=top_k)

    @app.get("/api/memory/search")
    async def search_memory(
        customer_id: str,
        query: str,
        tenant_id: str = config.DEFAULT_TENANT_ID,
        top_k: int = 5,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.search_memories(tenant_id, customer_id, query, top_k=top_k)

    @app.get("/api/memory/consent")
    async def get_memory_consent(
        customer_id: str,
        tenant_id: str = config.DEFAULT_TENANT_ID,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.get_memory_consent(tenant_id, customer_id)

    @app.patch("/api/memory/consent")
    async def set_memory_consent(
        request: MemoryConsentRequest,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.set_memory_consent(request.tenant_id, request.customer_id, request.status)

    @app.post("/api/memory")
    async def add_memory(
        request: MemoryAddRequest,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        try:
            return await service.add_memory(
                request.tenant_id,
                request.customer_id,
                request.text,
                infer=request.infer,
            )
        except Exception as exc:  # noqa: BLE001
            raise HTTPException(status_code=400, detail=str(exc)) from exc

    @app.patch("/api/memory/{memory_id}")
    async def update_memory(
        memory_id: str,
        request: MemoryUpdateRequest,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        try:
            return await service.update_memory(
                request.tenant_id,
                request.customer_id,
                memory_id,
                request.text,
            )
        except PermissionError as exc:
            raise HTTPException(status_code=403, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @app.get("/api/memory/{memory_id}")
    async def get_memory(
        memory_id: str,
        customer_id: str,
        tenant_id: str = config.DEFAULT_TENANT_ID,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        try:
            return await service.get_memory(tenant_id, customer_id, memory_id)
        except PermissionError as exc:
            raise HTTPException(status_code=403, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @app.delete("/api/memory/{memory_id}")
    async def delete_memory(
        memory_id: str,
        customer_id: str,
        tenant_id: str = config.DEFAULT_TENANT_ID,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        try:
            return await service.delete_memory(tenant_id, customer_id, memory_id)
        except PermissionError as exc:
            raise HTTPException(status_code=403, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @app.delete("/api/memory")
    async def delete_all_memory(
        customer_id: str,
        tenant_id: str = config.DEFAULT_TENANT_ID,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.delete_all_memories(tenant_id, customer_id)

    @app.get("/api/memory/{memory_id}/history")
    async def memory_history(
        memory_id: str,
        customer_id: str,
        tenant_id: str = config.DEFAULT_TENANT_ID,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        try:
            return await service.memory_history(tenant_id, customer_id, memory_id)
        except PermissionError as exc:
            raise HTTPException(status_code=403, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @app.get("/api/knowledge")
    async def list_knowledge(
        tenant_id: str = config.DEFAULT_TENANT_ID,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.list_knowledge(tenant_id)

    @app.get("/api/knowledge/search")
    async def search_knowledge(
        query: str,
        tenant_id: str = config.DEFAULT_TENANT_ID,
        limit: int = 3,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.search_knowledge(tenant_id, query, limit=limit)

    @app.get("/api/handoffs")
    async def list_handoffs(
        tenant_id: str = config.DEFAULT_TENANT_ID,
        status: str | None = None,
        limit: int = 20,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.list_handoffs(tenant_id, status=status, limit=limit)

    @app.patch("/api/handoffs/{handoff_id}")
    async def update_handoff_status(
        handoff_id: int,
        request: HandoffStatusRequest,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        try:
            return await service.update_handoff_status(request.tenant_id, handoff_id, request.status)
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @app.get("/api/analytics")
    async def analytics(
        tenant_id: str = config.DEFAULT_TENANT_ID,
        customer_id: str | None = None,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        return await service.support_analytics(tenant_id, customer_id=customer_id)

    @app.post("/api/consolidate")
    async def consolidate(
        request: ConsolidateRequest,
        session: str | None = Cookie(default=None),
    ):
        await guard(session)
        removed = await service.consolidate(request.tenant_id, request.customer_id)
        return {"removed": removed}

    return app


app = create_app()
