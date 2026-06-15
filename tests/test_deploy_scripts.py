from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1] / "scripts"
DEPLOY_SCRIPTS = [
    SCRIPT_DIR / "deploy-eci-source.ps1",
    SCRIPT_DIR / "update-eci-source.ps1",
]


def test_eci_nginx_proxy_supports_long_streaming_chat_responses():
    for path in DEPLOY_SCRIPTS:
        script = path.read_text(encoding="utf-8")

        assert "proxy_read_timeout 300s;" in script
        assert "proxy_send_timeout 300s;" in script
        assert "proxy_buffering off;" in script
        assert "proxy_request_buffering off;" in script
        assert "add_header X-Accel-Buffering no;" in script
