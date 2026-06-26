"""Logging food/exercise and seeing it aggregated in the daily report."""

import io
import json

from PIL import Image

from tests.conftest import auth_header, register_and_login


def _set_profile(client, token, **overrides):
    profile = {
        "weight_kg": 80,
        "height_cm": 180,
        "age": 30,
        "sex": "male",
        "activity_level": "moderate",
        "goal": "maintain",
        "timezone": "UTC",
    }
    profile.update(overrides)
    client.put("/profile", json=profile, headers=auth_header(token))


def _jpeg_with_exif() -> bytes:
    """A tiny JPEG carrying an EXIF tag, to prove stripping happens."""
    img = Image.new("RGB", (8, 8), (123, 50, 200))
    exif = Image.Exif()
    exif[0x010F] = "TestCameraMaker"  # Make tag
    buf = io.BytesIO()
    img.save(buf, format="JPEG", exif=exif)
    return buf.getvalue()


def test_log_food_recomputes_calories_server_side(client):
    token = register_and_login(client)
    _set_profile(client, token)
    resp = client.post(
        "/log/food",
        data={"items": json.dumps({"items": [{"dish": "nasi lemak"}]})},
        headers=auth_header(token),
    )
    assert resp.status_code == 201, resp.text
    entry = resp.json()[0]
    # Default 300 g nasi lemak * seeded 200 kcal/100g = 600.
    assert entry["grams"] == 300.0
    assert entry["gram_source"] == "estimate"
    assert entry["kcal"] == 600.0


def test_log_exercise_computes_from_mets(client):
    token = register_and_login(client)
    _set_profile(client, token)
    resp = client.post(
        "/log/exercise",
        json={"activity": "walking", "minutes": 30},
        headers=auth_header(token),
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    # MET 3.5 * 80 kg * 0.5 h = 140.
    assert body["kcal"] == 140.0
    assert body["source"] == "computed"


def test_logged_items_appear_in_todays_report(client):
    token = register_and_login(client)
    _set_profile(client, token)
    client.post(
        "/log/food",
        data={"items": json.dumps({"items": [{"dish": "nasi lemak"}]})},
        headers=auth_header(token),
    )
    client.post(
        "/log/exercise",
        json={"activity": "walking", "minutes": 30},
        headers=auth_header(token),
    )
    resp = client.get("/report/today", headers=auth_header(token))
    assert resp.status_code == 200
    r = resp.json()
    assert r["total_intake_kcal"] == 600.0
    assert r["total_burned_kcal"] == 140.0
    assert r["net_kcal"] == 460.0
    assert r["target_kcal"] == round(1780.0 * 1.55, 1)
    assert r["remaining_kcal"] == round(r["target_kcal"] - 460.0, 1)
    assert len(r["meals"]) == 1
    assert len(r["exercises"]) == 1
    assert "not medical advice" in r["note"].lower()


def test_direct_kcal_exercise(client):
    token = register_and_login(client)
    _set_profile(client, token)
    resp = client.post(
        "/log/exercise",
        json={"activity": "surfing", "kcal": 250},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    assert resp.json()["source"] == "user"
    assert resp.json()["kcal"] == 250.0


def test_meal_image_is_exif_stripped(client):
    from PIL import Image as PILImage

    token = register_and_login(client)
    _set_profile(client, token)
    resp = client.post(
        "/log/food",
        data={"items": json.dumps({"items": [{"dish": "nasi lemak"}]})},
        files={"image": ("meal.jpg", _jpeg_with_exif(), "image/jpeg")},
        headers=auth_header(token),
    )
    assert resp.status_code == 201
    path = resp.json()[0]["image_path"]
    assert path and path.startswith("meals/")

    # Read the stored file back through the same storage backend and confirm
    # no EXIF survived.
    from app.config import get_settings
    from app.storage.local import LocalDiskStorage

    storage = LocalDiskStorage(get_settings().storage_dir)
    stored = storage.get(path)
    with PILImage.open(io.BytesIO(stored)) as img:
        assert not dict(img.getexif())


def test_training_copy_only_with_consent(client):
    from app.config import get_settings
    from app.storage.local import LocalDiskStorage

    token = register_and_login(client)
    _set_profile(client, token, allow_training_use=True)
    resp = client.post(
        "/log/food",
        data={"items": json.dumps({"items": [{"dish": "nasi lemak"}]})},
        files={"image": ("meal.jpg", _jpeg_with_exif(), "image/jpeg")},
        headers=auth_header(token),
    )
    assert resp.json()[0]["image_path"]
    # A consented training copy exists under the separate namespace.
    storage = LocalDiskStorage(get_settings().storage_dir)
    name = resp.json()[0]["image_path"].split("/", 1)[1]
    assert storage.get(f"training/{name}")
