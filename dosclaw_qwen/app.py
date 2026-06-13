"""FastAPI application for the DOSClaw-Qwen demo."""

from __future__ import annotations

import json
import secrets
from pathlib import Path
from typing import Any

from fastapi import Cookie, FastAPI, HTTPException, Request, Response
from fastapi.responses import FileResponse, HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import config
from .chat_service import ChatService


class ChatRequest(BaseModel):
    customer_id: str = Field(min_length=1)
    message: str = Field(min_length=1)
    tenant_id: str = config.DEFAULT_TENANT_ID


class ConsolidateRequest(BaseModel):
    customer_id: str = Field(min_length=1)
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

    @app.get("/api/health")
    async def health():
        return {"ok": True, "service": "dosclaw-qwen"}

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
