from pathlib import Path


WEB_INDEX = Path(__file__).resolve().parents[1] / "web" / "index.html"


def test_web_ui_includes_demo_guide_and_runtime_badge():
    html = WEB_INDEX.read_text(encoding="utf-8")

    assert "Judge the memory, not a canned script." in html
    assert "Demo guide" in html
    assert "Memory controls" in html
    assert "Profile & consent" in html
    assert "Staff handoffs" in html
    assert "Support analytics" in html
    assert "Knowledge base" in html
    assert "id=\"tenant\"" in html
    assert "data-prompt=\"I'm JOY, 18 YO\"" in html
    assert "id=\"runtimeBadge\"" in html
    assert "id=\"runtimeDetail\"" in html
    assert "id=\"analyticsStrip\"" in html
    assert "id=\"memoryList\"" in html
    assert "id=\"profilePanel\"" in html
    assert "id=\"handoffList\"" in html
    assert "id=\"knowledgeList\"" in html
    assert "/api/tenants" in html
    assert "/api/memory" in html
    assert "/api/memory/consent" in html
    assert "/api/handoffs" in html
    assert "/api/analytics" in html
    assert "/api/knowledge" in html


def test_web_ui_surfaces_judge_friendly_demo_flow_above_the_chat():
    html = WEB_INDEX.read_text(encoding="utf-8")

    assert "class=\"scenario-strip\"" in html
    assert "data-action=\"teach-fact\"" in html
    assert "data-action=\"ask-recall\"" in html
    assert "data-action=\"switch-customer\"" in html
    assert "class=\"persona-rail\"" in html
    assert "id=\"personaRail\"" in html
    assert "function renderPersonaRail" in html
    assert "memory saved automatically" in html


def test_web_ui_makes_agent_metadata_and_inspector_sections_scannable():
    html = WEB_INDEX.read_text(encoding="utf-8")

    assert "message-role" in html
    assert "meta-chip" in html
    assert "class=\"inspector-card\"" in html
    assert "class=\"inspector-title\"" in html
    assert "class=\"inspector-nav\"" in html
    assert "Qwen Cloud" in html
    assert "AgentScope 2.0" in html


def test_web_ui_unlocks_composer_when_final_reply_arrives():
    html = WEB_INDEX.read_text(encoding="utf-8")

    assert "function lockComposer()" in html
    assert "function unlockComposer()" in html
    assert 'if (event.kind === "message")' in html
    message_handler = html.split('if (event.kind === "message")', 1)[1].split("};", 1)[0]
    assert "unlockComposer();" in message_handler


def test_web_ui_keeps_chat_composer_pinned_to_viewport():
    html = WEB_INDEX.read_text(encoding="utf-8")

    app_rule = html.split(".app {", 1)[1].split("}", 1)[0]
    main_rule = html.split("main {", 1)[1].split("}", 1)[0]
    thread_rule = html.split(".thread {", 1)[1].split("}", 1)[0]
    composer_rule = html.split(".composer {", 1)[1].split("}", 1)[0]

    assert "height: 100vh;" in app_rule
    assert "overflow: hidden;" in app_rule
    assert "overflow: hidden;" in main_rule
    assert "flex: 1 1 420px;" in thread_rule
    assert "min-height: 320px;" in thread_rule
    assert "position: sticky;" in composer_rule
    assert "bottom: 0;" in composer_rule


def test_web_ui_keeps_desktop_demo_chrome_compact():
    html = WEB_INDEX.read_text(encoding="utf-8")

    demo_rule = html.split(".demo-banner {", 1)[1].split("}", 1)[0]
    scenario_rule = html.split(".scenario-card {", 1)[1].split("}", 1)[0]
    persona_rule = html.split(".persona-card {", 1)[1].split("}", 1)[0]
    analytics_rule = html.split(".analytics-strip {", 1)[1].split("}", 1)[0]

    assert "padding: 10px 22px 8px;" in demo_rule
    assert "min-height: 52px;" in scenario_rule
    assert "padding: 7px 9px;" in persona_rule
    assert "flex-wrap: nowrap;" in analytics_rule


def test_web_ui_mobile_rules_prevent_horizontal_overflow():
    html = WEB_INDEX.read_text(encoding="utf-8")

    assert ".brand-row > div { min-width: 0; }" in html
    assert ".demo-content { min-width: 0; }" in html
    assert ".controls { width: 100%;" in html
    assert ".composer { width: 100%;" in html
    assert ".composer { position: fixed;" in html
    assert "padding-bottom: 140px;" in html
    assert "max-width: 100vw;" in html
    assert "Enter to send" not in html
    assert "Shift+Enter" not in html
