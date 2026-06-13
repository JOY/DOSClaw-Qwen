from dosclaw_qwen.ranking import decay_score, merge_profile, rank_episodes


def test_rank_blends_similarity_and_recency():
    episodes = [
        {"id": 1, "similarity": 0.9, "age_days": 30, "importance": 0.5},
        {"id": 2, "similarity": 0.6, "age_days": 0, "importance": 0.5},
        {"id": 3, "similarity": 0.2, "age_days": 1, "importance": 0.1},
    ]

    top = rank_episodes(episodes, k=2)

    assert [episode["id"] for episode in top] == [1, 2]
    assert all("score" in episode for episode in top)


def test_decay_score_drops_with_age_rises_with_importance():
    assert decay_score(importance=0.9, age_days=0) > decay_score(
        importance=0.9,
        age_days=60,
    )
    assert decay_score(importance=0.9, age_days=10) > decay_score(
        importance=0.1,
        age_days=10,
    )


def test_merge_profile_overrides_conflicts():
    old = {"prefers": "cow milk", "size": "M"}
    new = {"prefers": "oat milk"}

    merged = merge_profile(old, new)

    assert merged == {"prefers": "oat milk", "size": "M"}

