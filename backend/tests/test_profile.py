"""Profile update + computed summary (BMI, target, disclaimers)."""

from tests.conftest import auth_header, register_and_login


def _full_profile() -> dict:
    return {
        "weight_kg": 80,
        "height_cm": 180,
        "age": 30,
        "sex": "male",
        "activity_level": "moderate",
        "goal": "maintain",
        "timezone": "Asia/Kuala_Lumpur",
    }


def test_update_then_summary_has_computed_fields(client):
    token = register_and_login(client)
    resp = client.put("/profile", json=_full_profile(), headers=auth_header(token))
    assert resp.status_code == 200
    body = resp.json()
    assert body["weight_kg"] == 80
    assert body["bmi"] == 24.7
    assert body["bmi_note"] and "muscle" in body["bmi_note"].lower()
    # BMR 1780 -> TDEE *1.55 -> maintain == TDEE.
    assert body["target_kcal"] == round(1780.0 * 1.55, 1)
    assert body["activity_guidance"]


def test_partial_update_keeps_other_fields(client):
    token = register_and_login(client)
    client.put("/profile", json=_full_profile(), headers=auth_header(token))
    resp = client.put("/profile", json={"goal": "lose"}, headers=auth_header(token))
    body = resp.json()
    assert body["goal"] == "lose"
    assert body["weight_kg"] == 80  # untouched
    assert body["target_kcal"] == round(1780.0 * 1.55, 1) - 500.0


def test_incomplete_profile_has_no_target(client):
    token = register_and_login(client)
    resp = client.put("/profile", json={"weight_kg": 80}, headers=auth_header(token))
    body = resp.json()
    assert body["target_kcal"] is None  # not enough stats yet
    assert body["bmi"] is None  # height missing


def test_invalid_timezone_rejected(client):
    token = register_and_login(client)
    resp = client.put(
        "/profile", json={"timezone": "Mars/Olympus"}, headers=auth_header(token)
    )
    assert resp.status_code == 422


def test_toggle_training_consent(client):
    token = register_and_login(client)
    resp = client.put(
        "/profile", json={"allow_training_use": True}, headers=auth_header(token)
    )
    assert resp.json()["allow_training_use"] is True


def test_register_with_username_shows_in_summary_and_social(client):
    resp = client.post(
        "/auth/register",
        json={"email": "nick@example.com", "password": "password123",
              "username": "Nick the Runner"},
    )
    assert resp.status_code == 201
    token = resp.json()["access_token"]
    summary = client.get("/profile", headers=auth_header(token)).json()
    assert summary["username"] == "Nick the Runner"


def test_username_editable_via_profile_update(client):
    token = register_and_login(client)
    resp = client.put(
        "/profile", json={"username": "  Renamed  "}, headers=auth_header(token)
    )
    assert resp.status_code == 200
    assert resp.json()["username"] == "Renamed"  # trimmed


def test_custom_target_override_wins_and_clamps(client):
    token = register_and_login(client)
    # Override with no stats at all still yields a target.
    resp = client.put(
        "/profile", json={"target_kcal_override": 1800}, headers=auth_header(token)
    )
    body = resp.json()
    assert body["target_kcal"] == 1800
    assert body["target_kcal_override"] == 1800
    assert body["target_is_custom"] is True

    # Below the safe floor is clamped up to 1200.
    resp = client.put(
        "/profile", json={"target_kcal_override": 800}, headers=auth_header(token)
    )
    assert resp.json()["target_kcal"] == 1200.0

    # The override also drives the daily report.
    report = client.get("/report/today", headers=auth_header(token)).json()
    assert report["target_kcal"] == 1200.0


def test_clearing_target_override_reverts_to_computed(client):
    token = register_and_login(client)
    client.put("/profile", json=_full_profile(), headers=auth_header(token))
    computed = round(1780.0 * 1.55, 1)

    client.put(
        "/profile", json={"target_kcal_override": 1500}, headers=auth_header(token)
    )
    # Explicit null clears the override -> back to the computed target.
    resp = client.put(
        "/profile", json={"target_kcal_override": None}, headers=auth_header(token)
    )
    body = resp.json()
    assert body["target_is_custom"] is False
    assert body["target_kcal"] == computed
