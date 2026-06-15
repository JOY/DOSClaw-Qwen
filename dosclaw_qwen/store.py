"""Async Postgres access for tenant data, profiles, knowledge, and handoffs."""

from __future__ import annotations

import json
from typing import Any

import asyncpg

from . import config

_pool: asyncpg.Pool | None = None


async def pool() -> asyncpg.Pool:
    """Return the shared asyncpg pool."""
    global _pool
    if _pool is None:
        _pool = await asyncpg.create_pool(config.DATABASE_URL, min_size=1, max_size=5)
    return _pool


async def close_pool() -> None:
    """Close the shared asyncpg pool."""
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None


def vector_literal(values: list[float]) -> str:
    """Format a Python vector for pgvector casts."""
    return "[" + ",".join(str(float(value)) for value in values) + "]"


def parse_json_object(value: Any) -> dict[str, Any]:
    """Return a JSON object from asyncpg json/jsonb values."""
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            return {}
        return parsed if isinstance(parsed, dict) else {}
    return {}


class Store:
    """Database facade used by the app and memory service."""

    async def list_tenants(self) -> list[dict[str, Any]]:
        db = await pool()
        rows = await db.fetch(
            """
            select id, name
            from tenants
            order by created_at, id
            """,
        )
        return [dict(row) for row in rows]

    async def list_customers(self, tenant_id: str) -> list[dict[str, Any]]:
        db = await pool()
        rows = await db.fetch(
            """
            select id, name
            from customers
            where tenant_id=$1
            order by created_at, id
            """,
            tenant_id,
        )
        return [dict(row) for row in rows]

    async def get_profile(self, tenant_id: str, customer_id: str) -> dict[str, Any]:
        db = await pool()
        row = await db.fetchrow(
            """
            select facts
            from customer_profile
            where tenant_id=$1 and customer_id=$2
            """,
            tenant_id,
            customer_id,
        )
        if not row or not row["facts"]:
            return {}
        return parse_json_object(row["facts"])

    async def set_profile(
        self,
        tenant_id: str,
        customer_id: str,
        facts: dict[str, Any],
    ) -> None:
        db = await pool()
        await db.execute(
            """
            insert into customer_profile(tenant_id, customer_id, facts, updated_at)
            values($1, $2, $3::jsonb, now())
            on conflict (tenant_id, customer_id)
            do update set facts=excluded.facts, updated_at=now()
            """,
            tenant_id,
            customer_id,
            json.dumps(facts),
        )

    async def search_knowledge(
        self,
        tenant_id: str,
        query_embedding: list[float],
        limit: int = 3,
    ) -> list[dict[str, Any]]:
        db = await pool()
        rows = await db.fetch(
            """
            select title, content, 1 - (embedding <=> $2::vector) as similarity
            from knowledge
            where tenant_id=$1
            order by embedding <=> $2::vector
            limit $3
            """,
            tenant_id,
            vector_literal(query_embedding),
            limit,
        )
        return [dict(row) for row in rows]

    async def list_knowledge(self, tenant_id: str) -> list[dict[str, Any]]:
        db = await pool()
        rows = await db.fetch(
            """
            select id, title, content
            from knowledge
            where tenant_id=$1
            order by title
            """,
            tenant_id,
        )
        return [dict(row) for row in rows]

    async def add_knowledge(
        self,
        tenant_id: str,
        title: str,
        content: str,
        embedding: list[float],
    ) -> None:
        db = await pool()
        await db.execute(
            """
            insert into knowledge(tenant_id, title, content, embedding)
            values($1, $2, $3, $4::vector)
            on conflict (tenant_id, title)
            do update set content=excluded.content, embedding=excluded.embedding
            """,
            tenant_id,
            title,
            content,
            vector_literal(embedding),
        )

    async def log_handoff(self, tenant_id: str, customer_id: str, reason: str) -> int:
        db = await pool()
        return await db.fetchval(
            """
            insert into handoffs(tenant_id, customer_id, reason)
            values($1, $2, $3)
            returning id
            """,
            tenant_id,
            customer_id,
            reason,
        )

    async def list_handoffs(
        self,
        tenant_id: str,
        status: str | None = None,
        limit: int = 20,
    ) -> list[dict[str, Any]]:
        db = await pool()
        rows = await db.fetch(
            """
            select
              h.id,
              h.tenant_id,
              h.customer_id,
              coalesce(c.name, h.customer_id) as customer_name,
              h.reason,
              h.status,
              h.created_at
            from handoffs h
            left join customers c
              on c.tenant_id = h.tenant_id
             and c.id = h.customer_id
            where h.tenant_id = $1
              and ($2::text is null or h.status = $2)
            order by h.created_at desc, h.id desc
            limit $3
            """,
            tenant_id,
            status,
            limit,
        )
        return [dict(row) for row in rows]

    async def update_handoff_status(self, tenant_id: str, handoff_id: int, status: str) -> dict[str, Any]:
        db = await pool()
        row = await db.fetchrow(
            """
            update handoffs
            set status = $3
            where tenant_id = $1 and id = $2
            returning id, tenant_id, customer_id, reason, status, created_at
            """,
            tenant_id,
            handoff_id,
            status,
        )
        if not row:
            raise ValueError(f"Handoff ticket {handoff_id} was not found.")
        return dict(row)

    async def support_analytics(self, tenant_id: str) -> dict[str, Any]:
        db = await pool()
        row = await db.fetchrow(
            """
            select
              (select count(*) from customers where tenant_id=$1) as customers,
              (select count(*) from customer_profile where tenant_id=$1 and facts <> '{}'::jsonb) as profiles,
              (select count(*) from knowledge where tenant_id=$1) as knowledge_rows,
              (select count(*) from handoffs where tenant_id=$1 and status='open') as handoffs_open,
              (select count(*) from handoffs where tenant_id=$1) as handoffs_total
            """,
            tenant_id,
        )
        return dict(row or {})

    async def search_memories(
        self,
        tenant_id: str,
        customer_id: str,
        query: str,
        limit: int = 20,
    ) -> list[dict[str, Any]]:
        return []
