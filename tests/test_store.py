from dosclaw_qwen.store import parse_json_object


def test_parse_json_object_accepts_dict_and_json_string():
    assert parse_json_object({"prefers": "oat milk"}) == {"prefers": "oat milk"}
    assert parse_json_object('{"prefers":"oat milk"}') == {"prefers": "oat milk"}


def test_parse_json_object_falls_back_to_empty_dict():
    assert parse_json_object(None) == {}
    assert parse_json_object("not-json") == {}
    assert parse_json_object(["not", "object"]) == {}
