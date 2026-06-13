param(
    [Parameter(Mandatory = $true)]
    [string]$HostName,

    [string]$User = "root",
    [int]$SshPort = 22,
    [string]$RemoteDir = "/opt/dosclaw-qwen",
    [string]$RepoUrl = "https://github.com/JOY/DOSClaw-Qwen.git",
    [string]$Branch = "main",
    [int]$AppPort = 8092,
    [string]$DemoLoginUser = "judge",
    [string]$DemoLoginPass = $env:DEMO_LOGIN_PASS
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

if ([string]::IsNullOrWhiteSpace($env:DASHSCOPE_API_KEY)) {
    throw "Set DASHSCOPE_API_KEY in the local environment before deploying."
}

$dashscopeBaseUrl = if ($env:DASHSCOPE_BASE_URL) {
    $env:DASHSCOPE_BASE_URL
} else {
    "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
}
$qwenChatModel = if ($env:QWEN_CHAT_MODEL) { $env:QWEN_CHAT_MODEL } else { "qwen3.6-plus" }
$qwenEmbedModel = if ($env:QWEN_EMBED_MODEL) { $env:QWEN_EMBED_MODEL } else { "text-embedding-v4" }
$embedDim = if ($env:EMBED_DIM) { $env:EMBED_DIM } else { "1024" }

$remote = "$User@$HostName"
$envFile = @"
DASHSCOPE_API_KEY=$env:DASHSCOPE_API_KEY
DASHSCOPE_BASE_URL=$dashscopeBaseUrl
QWEN_CHAT_MODEL=$qwenChatModel
QWEN_EMBED_MODEL=$qwenEmbedModel
EMBED_DIM=$embedDim
DATABASE_URL=postgresql://dosclaw_qwen:dosclaw_qwen@db:5432/dosclaw_qwen
DEFAULT_TENANT_ID=tenant_demo
MEM0_QDRANT_PATH=.mem0/qdrant
DEMO_LOGIN_USER=$DemoLoginUser
DEMO_LOGIN_PASS=$DemoLoginPass
"@
$envB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($envFile))

function ConvertTo-ShSingleQuoted {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        $Value = ""
    }

    return "'" + $Value.Replace("'", "'""'""'") + "'"
}

$remoteScript = @'
set -eu

REMOTE_DIR=__REMOTE_DIR__
BRANCH=__BRANCH__
REPO_URL=__REPO_URL__
ENV_B64=__ENV_B64__
APP_PORT=__APP_PORT__
COMPOSE_NETWORK="$(basename "$REMOTE_DIR")_default"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required on the ECS host." >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose is required on the ECS host." >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "git is required on the ECS host." >&2
  exit 1
fi
mkdir -p "$REMOTE_DIR"
if [ ! -d "$REMOTE_DIR/.git" ]; then
  git clone --branch "$BRANCH" "$REPO_URL" "$REMOTE_DIR"
else
  git -C "$REMOTE_DIR" fetch origin "$BRANCH"
  git -C "$REMOTE_DIR" checkout "$BRANCH"
  git -C "$REMOTE_DIR" pull --ff-only origin "$BRANCH"
fi
printf '%s' "$ENV_B64" | base64 -d > "$REMOTE_DIR/.env"
chmod 600 "$REMOTE_DIR/.env"
cd "$REMOTE_DIR"
docker compose up -d db
db_ready=0
i=1
while [ "$i" -le 30 ]; do
  if docker compose exec -T db pg_isready -U dosclaw_qwen -d dosclaw_qwen >/dev/null 2>&1; then
    db_ready=1
    break
  fi
  i=$((i + 1))
  sleep 2
done
if [ "$db_ready" -ne 1 ]; then
  echo "Postgres did not become ready in time." >&2
  exit 1
fi
docker build -t dosclaw-qwen:latest .
docker rm -f dosclaw-qwen-app >/dev/null 2>&1 || true
docker run -d --name dosclaw-qwen-app --restart unless-stopped \
  --env-file .env --network "$COMPOSE_NETWORK" \
  -p "$APP_PORT:8092" dosclaw-qwen:latest
docker compose exec -T db psql -U dosclaw_qwen -d dosclaw_qwen -v ON_ERROR_STOP=1 < db/schema.sql
docker compose exec -T db psql -U dosclaw_qwen -d dosclaw_qwen -v ON_ERROR_STOP=1 < db/seed.sql
docker exec dosclaw-qwen-app python -m dosclaw_qwen.seed_embeddings
app_ready=0
i=1
while [ "$i" -le 30 ]; do
  if curl -fsS "http://127.0.0.1:$APP_PORT/api/health"; then
    app_ready=1
    break
  fi
  i=$((i + 1))
  sleep 2
done
if [ "$app_ready" -ne 1 ]; then
  echo "DOSClaw-Qwen did not become healthy in time." >&2
  exit 1
fi
'@

$remoteScript = $remoteScript.Replace("__REMOTE_DIR__", (ConvertTo-ShSingleQuoted $RemoteDir))
$remoteScript = $remoteScript.Replace("__BRANCH__", (ConvertTo-ShSingleQuoted $Branch))
$remoteScript = $remoteScript.Replace("__REPO_URL__", (ConvertTo-ShSingleQuoted $RepoUrl))
$remoteScript = $remoteScript.Replace("__ENV_B64__", (ConvertTo-ShSingleQuoted $envB64))
$remoteScript = $remoteScript.Replace("__APP_PORT__", (ConvertTo-ShSingleQuoted ([string]$AppPort)))

Write-Host "Deploying DOSClaw-Qwen to ${remote}:${RemoteDir} ..."
$remoteScript | ssh -p $SshPort $remote "sh -s"
Write-Host "Remote health check passed. Public test URL should be http://${HostName}:${AppPort} if the security group allows inbound traffic."
