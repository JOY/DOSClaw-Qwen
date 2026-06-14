from pathlib import Path


WEB_INDEX = Path(__file__).resolve().parents[1] / "web" / "index.html"


def test_web_ui_includes_demo_guide_and_runtime_badge():
    html = WEB_INDEX.read_text(encoding="utf-8")

    assert "Judge the memory, not a canned script." in html
    assert "Demo guide" in html
    assert "data-prompt=\"I'm JOY, 18 YO\"" in html
    assert "id=\"runtimeBadge\"" in html
    assert "id=\"runtimeDetail\"" in html
