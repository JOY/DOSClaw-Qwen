"""Runtime configuration loaded from environment variables."""

from __future__ import annotations

import os

from dotenv import load_dotenv

load_dotenv()

DASHSCOPE_API_KEY = os.environ.get("DASHSCOPE_API_KEY", "")
DASHSCOPE_BASE_URL = os.environ.get(
    "DASHSCOPE_BASE_URL",
    "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
)
QWEN_CHAT_MODEL = os.environ.get("QWEN_CHAT_MODEL", "qwen3.6-plus")
QWEN_EMBED_MODEL = os.environ.get("QWEN_EMBED_MODEL", "text-embedding-v4")
EMBED_DIM = int(os.environ.get("EMBED_DIM", "1024"))
DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://dosclaw_qwen:dosclaw_qwen@localhost:5432/dosclaw_qwen",
)
DEFAULT_TENANT_ID = os.environ.get("DEFAULT_TENANT_ID", "tenant_demo")
MEM0_QDRANT_PATH = os.environ.get("MEM0_QDRANT_PATH", ".mem0/qdrant")
DEMO_LOGIN_USER = os.environ.get("DEMO_LOGIN_USER", "judge")
DEMO_LOGIN_PASS = os.environ.get("DEMO_LOGIN_PASS", "")
