from pathlib import Path


WEB_INDEX = Path(__file__).resolve().parents[1] / "web" / "index.html"


def test_web_ui_includes_demo_guide_and_runtime_badge():
    html = WEB_INDEX.read_text(encoding="utf-8")

    assert "Judge the memory, not a canned script." in html
    assert "Demo guide" in html
    assert "Memory controls" in html
    assert "Knowledge base" in html
    assert "data-prompt=\"I'm JOY, 18 YO\"" in html
    assert "id=\"runtimeBadge\"" in html
    assert "id=\"runtimeDetail\"" in html
    assert "id=\"memoryList\"" in html
    assert "id=\"knowledgeList\"" in html
    assert "/api/memory" in html
    assert "/api/knowledge" in html


def test_web_ui_unlocks_composer_when_final_reply_arrives():
    html = WEB_INDEX.read_text(encoding="utf-8")

    assert "function lockComposer()" in html
    assert "function unlockComposer()" in html
    assert 'if (event.kind === "message")' in html
    message_handler = html.split('if (event.kind === "message")', 1)[1].split("};", 1)[0]
    assert "unlockComposer();" in message_handler
