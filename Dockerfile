FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8092

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY dosclaw_qwen ./dosclaw_qwen
COPY web ./web
COPY db ./db
COPY README.md LICENSE ./

EXPOSE 8092

CMD ["sh", "-c", "uvicorn dosclaw_qwen.app:app --host 0.0.0.0 --port ${PORT:-8092}"]
