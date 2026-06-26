"""Authenticated image serving: owners can fetch their own meal image; others
get a 404, and traversal/unauth requests are refused.
"""

import io
import json

from PIL import Image

from tests.conftest import auth_header, register_and_login


def _jpeg() -> bytes:
    img = Image.new("RGB", (8, 8), (10, 120, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def _log_food_with_image(client, token) -> str:
    resp = client.post(
        "/log/food",
        data={"items": json.dumps({"items": [{"dish": "nasi lemak"}]})},
        files={"image": ("meal.jpg", _jpeg(), "image/jpeg")},
        headers=auth_header(token),
    )
    assert resp.status_code == 201, resp.text
    path = resp.json()[0]["image_path"]
    assert path and path.startswith("meals/")
    return path


def test_owner_can_fetch_their_image(client):
    token = register_and_login(client)
    path = _log_food_with_image(client, token)

    resp = client.get(f"/images/{path}", headers=auth_header(token))
    assert resp.status_code == 200, resp.text
    assert resp.headers["content-type"] == "image/jpeg"
    with Image.open(io.BytesIO(resp.content)) as img:
        assert img.size == (8, 8)


def test_other_user_cannot_fetch_someone_elses_image(client):
    owner = register_and_login(client, email="owner@example.com")
    other = register_and_login(client, email="other@example.com")
    path = _log_food_with_image(client, owner)

    resp = client.get(f"/images/{path}", headers=auth_header(other))
    assert resp.status_code == 404


def test_unauthenticated_request_is_rejected(client):
    token = register_and_login(client)
    path = _log_food_with_image(client, token)

    resp = client.get(f"/images/{path}")  # no Authorization header
    assert resp.status_code in (401, 403)


def test_traversal_ref_is_not_served(client):
    token = register_and_login(client)
    _log_food_with_image(client, token)

    resp = client.get("/images/meals/../../secret.txt", headers=auth_header(token))
    assert resp.status_code == 404


# --- shared-image visibility (App Phase 3 / backend §B) ----------------------


def _uid(client, token, handle) -> int:
    r = client.get(f"/friends/search?handle={handle}", headers=auth_header(token))
    assert r.status_code == 200, r.text
    for u in r.json():
        if u["handle"] == handle:
            return u["id"]
    raise AssertionError(f"{handle} not found")


def _befriend(client, ta, ea, tb, eb):
    bid = _uid(client, ta, eb)
    assert (
        client.post(
            "/friends/request", json={"addressee_id": bid}, headers=auth_header(ta)
        ).status_code
        == 201
    )
    aid = _uid(client, tb, ea)
    assert (
        client.post(
            "/friends/accept", json={"requester_id": aid}, headers=auth_header(tb)
        ).status_code
        == 200
    )


def _share_image_into_community(client, owner_token):
    """Owner logs a meal with an image, makes a community, and shares it (with
    food images) into that community. Returns (image_path, community_id)."""
    path = _log_food_with_image(client, owner_token)
    cid = client.post(
        "/community", json={"name": "Crew"}, headers=auth_header(owner_token)
    ).json()["id"]
    today = client.get(
        "/report/today", headers=auth_header(owner_token)
    ).json()["date"]
    r = client.post(
        "/share",
        json={
            "date": today,
            "community_ids": [cid],
            "parts": {"include_food_images": True},
        },
        headers=auth_header(owner_token),
    )
    assert r.status_code == 201, r.text
    # The shared snapshot carries the image path.
    assert any(
        img["image_path"] == path
        for img in r.json()[0]["payload"]["food_images"]
    )
    return path, cid


def test_community_member_can_load_shared_image(client):
    owner = register_and_login(client, email="owner@example.com")
    member = register_and_login(client, email="member@example.com")
    _befriend(client, owner, "owner@example.com", member, "member@example.com")

    path, cid = _share_image_into_community(client, owner)

    # The member joins the community...
    member_id = _uid(client, owner, "member@example.com")
    client.post(
        f"/community/{cid}/invite",
        json={"invitee_id": member_id},
        headers=auth_header(owner),
    )
    invite_id = client.get(
        "/community/invites", headers=auth_header(member)
    ).json()[0]["id"]
    client.post(f"/community/invite/{invite_id}/accept", headers=auth_header(member))

    # ...and can now load the shared image, despite not owning it.
    resp = client.get(f"/images/{path}", headers=auth_header(member))
    assert resp.status_code == 200, resp.text
    assert resp.headers["content-type"] == "image/jpeg"


def test_non_member_cannot_load_shared_image(client):
    owner = register_and_login(client, email="owner@example.com")
    outsider = register_and_login(client, email="out@example.com")

    path, _ = _share_image_into_community(client, owner)

    # The outsider is in no community the image was shared into.
    resp = client.get(f"/images/{path}", headers=auth_header(outsider))
    assert resp.status_code == 404
