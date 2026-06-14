"""Pure memory math for scoring recall candidates and merging profile facts."""

from __future__ import annotations

import math
from typing import Any

_IDENTITY_BOUND_KEYS = {
    "allergies",
    "dietary_restrictions",
    "last_order",
    "lactose_intolerant",
    "preferred_drink",
    "preferred_milk",
    "prefers",
}


def decay_score(
    importance: float,
    age_days: float,
    half_life_days: float = 21.0,
) -> float:
    """Return the current strength of a memory after exponential time decay."""
    bounded_importance = max(0.0, min(1.0, importance))
    bounded_age = max(0.0, age_days)
    recency = math.pow(0.5, bounded_age / half_life_days)
    return bounded_importance * recency


def rank_episodes(
    episodes: list[dict[str, Any]],
    k: int = 5,
    min_score: float = 0.15,
) -> list[dict[str, Any]]:
    """Blend semantic similarity with decayed importance and return the top memories."""
    scored = []
    for episode in episodes:
        similarity = max(0.0, min(1.0, float(episode.get("similarity", 0.0))))
        strength = decay_score(
            importance=float(episode.get("importance", 0.5)),
            age_days=float(episode.get("age_days", 0.0)),
        )
        score = 0.7 * similarity + 0.3 * strength
        scored.append({**episode, "score": score})

    ranked = [episode for episode in scored if episode["score"] >= min_score]
    ranked.sort(key=lambda episode: episode["score"], reverse=True)
    return ranked[:k]


def merge_profile(old: dict[str, Any], new: dict[str, Any]) -> dict[str, Any]:
    """Merge extracted profile facts, letting newer non-empty values win."""
    merged = dict(old)
    if _is_new_identity(old, new):
        for key in _IDENTITY_BOUND_KEYS:
            merged.pop(key, None)
    for key, value in new.items():
        if value is None or value == "":
            merged.pop(key, None)
        else:
            merged[key] = value
    return merged


def _is_new_identity(old: dict[str, Any], new: dict[str, Any]) -> bool:
    old_name = old.get("name")
    new_name = new.get("name")
    if not old_name or not new_name:
        return False
    return str(old_name).strip().casefold() != str(new_name).strip().casefold()
