"""Phase 3 social-layer integration tests: friends, friend-gated invites, the
10-member cap, explicit-only sharing with minimum-share defaults, and reactions.
"""

import json

from tests.conftest import auth_header


# --- helpers -----------------------------------------------------------------


def reg(client, email):
    r = client.post("/auth/register", json={"email": email, "password": "password123"})
    assert r.status_code == 201, r.text
    return r.json()["access_token"]


def uid(client, token, handle):
    r = client.get(f"/friends/search?handle={handle}", headers=auth_header(token))
    assert r.status_code == 200, r.text
    for u in r.json():
        if u["handle"] == handle:
            return u["id"]
    raise AssertionError(f"{handle} not found in search")


def befriend(client, token_a, email_a, token_b, email_b):
    """a requests b, b accepts."""
    b_id = uid(client, token_a, email_b)
    r = client.post(
        "/friends/request", json={"addressee_id": b_id}, headers=auth_header(token_a)
    )
    assert r.status_code == 201, r.text
    a_id = uid(client, token_b, email_a)
    r = client.post(
        "/friends/accept", json={"requester_id": a_id}, headers=auth_header(token_b)
    )
    assert r.status_code == 200, r.text


def log_a_meal(client, token):
    r = client.post(
        "/log/food",
        data={"items": json.dumps({"items": [{"dish": "nasi lemak"}]})},
        headers=auth_header(token),
    )
    assert r.status_code == 201, r.text


# --- friends -----------------------------------------------------------------


def test_friend_request_accept_appears_in_list(client):
    ta = reg(client, "a@example.com")
    tb = reg(client, "b@example.com")
    befriend(client, ta, "a@example.com", tb, "b@example.com")

    friends_a = client.get("/friends", headers=auth_header(ta)).json()
    assert [f["handle"] for f in friends_a] == ["b@example.com"]
    friends_b = client.get("/friends", headers=auth_header(tb)).json()
    assert [f["handle"] for f in friends_b] == ["a@example.com"]


def test_search_excludes_self_and_hides_stats(client):
    ta = reg(client, "a@example.com")
    reg(client, "ab@example.com")
    results = client.get("/friends/search?handle=a", headers=auth_header(ta)).json()
    handles = {u["handle"] for u in results}
    assert "ab@example.com" in handles
    assert "a@example.com" not in handles  # self excluded
    # Only safe fields exposed.
    assert set(results[0]) == {"id", "handle", "display_name"}


# --- communities & friend-gated invites --------------------------------------


def test_invite_non_friend_rejected_friend_works(client):
    owner = reg(client, "owner@example.com")
    stranger = reg(client, "stranger@example.com")
    friend = reg(client, "friend@example.com")

    cid = client.post(
        "/community", json={"name": "Crew"}, headers=auth_header(owner)
    ).json()["id"]

    # Inviting a non-friend is rejected.
    stranger_id = uid(client, owner, "stranger@example.com")
    r = client.post(
        f"/community/{cid}/invite",
        json={"invitee_id": stranger_id},
        headers=auth_header(owner),
    )
    assert r.status_code == 403

    # Inviting an accepted friend works.
    befriend(client, owner, "owner@example.com", friend, "friend@example.com")
    friend_id = uid(client, owner, "friend@example.com")
    r = client.post(
        f"/community/{cid}/invite",
        json={"invitee_id": friend_id},
        headers=auth_header(owner),
    )
    assert r.status_code == 201


def test_community_capped_at_ten_members(client):
    owner = reg(client, "owner@example.com")
    cid = client.post(
        "/community", json={"name": "Crew"}, headers=auth_header(owner)
    ).json()["id"]

    # Owner is member #1. Add friends until full, then one more must fail.
    last_status = None
    for i in range(12):
        email = f"f{i}@example.com"
        tok = reg(client, email)
        befriend(client, owner, "owner@example.com", tok, email)
        fid = uid(client, owner, email)
        client.post(
            f"/community/{cid}/invite",
            json={"invitee_id": fid},
            headers=auth_header(owner),
        )
        # Find the invite id from the invitee side and accept.
        invites = client.get("/community/invites", headers=auth_header(tok)).json()
        invite_id = invites[0]["id"]
        last = client.post(
            f"/community/invite/{invite_id}/accept", headers=auth_header(tok)
        )
        last_status = last.status_code
        members = client.get(f"/community/{cid}", headers=auth_header(owner)).json()
        if len(members) >= 10:
            # Once full (owner + 9), the next acceptance must be rejected.
            assert last_status in (200, 409)

    members = client.get(f"/community/{cid}", headers=auth_header(owner)).json()
    assert len(members) == 10  # never exceeded the cap
    assert last_status == 409  # the final attempt was rejected


# --- sharing is always explicit; minimum-share defaults ----------------------


def _solo_community(client, owner):
    return client.post(
        "/community", json={"name": "Solo"}, headers=auth_header(owner)
    ).json()["id"]


def test_nothing_in_feed_without_explicit_share(client):
    owner = reg(client, "owner@example.com")
    cid = _solo_community(client, owner)
    log_a_meal(client, owner)

    # No share yet -> empty feed, even though a meal was logged.
    feed = client.get(f"/feed/{cid}", headers=auth_header(owner)).json()
    assert feed == []

    # Explicit share -> exactly one post.
    today = client.get("/report/today", headers=auth_header(owner)).json()["date"]
    r = client.post(
        "/share",
        json={"date": today, "community_ids": [cid]},
        headers=auth_header(owner),
    )
    assert r.status_code == 201, r.text
    feed = client.get(f"/feed/{cid}", headers=auth_header(owner)).json()
    assert len(feed) == 1


def test_share_excludes_body_derived_by_default(client):
    owner = reg(client, "owner@example.com")
    # Complete profile so a target EXISTS and could leak if defaults were wrong.
    client.put(
        "/profile",
        json={
            "weight_kg": 80,
            "height_cm": 180,
            "age": 30,
            "sex": "male",
            "activity_level": "moderate",
            "goal": "maintain",
            "timezone": "UTC",
        },
        headers=auth_header(owner),
    )
    cid = _solo_community(client, owner)
    log_a_meal(client, owner)

    today = client.get("/report/today", headers=auth_header(owner)).json()["date"]
    r = client.post(
        "/share",
        json={"date": today, "community_ids": [cid]},
        headers=auth_header(owner),
    )
    assert r.status_code == 201, r.text
    payload = r.json()[0]["payload"]
    assert "net_kcal" in payload  # default on
    assert "target_kcal" not in payload  # body-derived, default off
    assert "remaining_kcal" not in payload


def test_share_with_target_included_when_explicit(client):
    owner = reg(client, "owner@example.com")
    client.put(
        "/profile",
        json={
            "weight_kg": 80, "height_cm": 180, "age": 30, "sex": "male",
            "activity_level": "moderate", "goal": "maintain", "timezone": "UTC",
        },
        headers=auth_header(owner),
    )
    cid = _solo_community(client, owner)
    log_a_meal(client, owner)
    today = client.get("/report/today", headers=auth_header(owner)).json()["date"]

    r = client.post(
        "/share",
        json={
            "date": today,
            "community_ids": [cid],
            "parts": {"include_target": True},
        },
        headers=auth_header(owner),
    )
    assert r.json()[0]["payload"]["target_kcal"] is not None


def test_share_requires_membership(client):
    owner = reg(client, "owner@example.com")
    outsider = reg(client, "out@example.com")
    cid = _solo_community(client, owner)
    today = client.get("/report/today", headers=auth_header(outsider)).json()["date"]
    r = client.post(
        "/share",
        json={"date": today, "community_ids": [cid]},
        headers=auth_header(outsider),
    )
    assert r.status_code == 403


# --- reactions ---------------------------------------------------------------


def _shared_post(client, owner, cid):
    today = client.get("/report/today", headers=auth_header(owner)).json()["date"]
    r = client.post(
        "/share",
        json={"date": today, "community_ids": [cid]},
        headers=auth_header(owner),
    )
    return r.json()[0]["id"]


def test_reaction_must_be_in_fixed_set(client):
    owner = reg(client, "owner@example.com")
    cid = _solo_community(client, owner)
    log_a_meal(client, owner)
    post_id = _shared_post(client, owner, cid)

    bad = client.post(
        f"/feed/{post_id}/react", json={"emoji": "x"}, headers=auth_header(owner)
    )
    assert bad.status_code == 422

    good = client.post(
        f"/feed/{post_id}/react", json={"emoji": "🔥"}, headers=auth_header(owner)
    )
    assert good.status_code == 200
    assert good.json()["counts"]["🔥"] == 1


def test_one_reaction_per_user_changes_not_duplicates(client):
    owner = reg(client, "owner@example.com")
    cid = _solo_community(client, owner)
    log_a_meal(client, owner)
    post_id = _shared_post(client, owner, cid)

    client.post(f"/feed/{post_id}/react", json={"emoji": "👍"}, headers=auth_header(owner))
    r = client.post(
        f"/feed/{post_id}/react", json={"emoji": "💪"}, headers=auth_header(owner)
    )
    counts = r.json()["counts"]
    assert counts == {"💪": 1}  # changed, not two rows
    assert r.json()["my_reaction"] == "💪"

    # Remove it.
    r = client.delete(f"/feed/{post_id}/react", headers=auth_header(owner))
    assert r.json()["counts"] == {}
    assert r.json()["my_reaction"] is None


def test_non_member_cannot_read_feed_or_react(client):
    owner = reg(client, "owner@example.com")
    outsider = reg(client, "out@example.com")
    cid = _solo_community(client, owner)
    log_a_meal(client, owner)
    post_id = _shared_post(client, owner, cid)

    assert client.get(f"/feed/{cid}", headers=auth_header(outsider)).status_code == 403
    r = client.post(
        f"/feed/{post_id}/react", json={"emoji": "👍"}, headers=auth_header(outsider)
    )
    assert r.status_code == 403


def test_member_sees_post_and_reaction_in_feed(client):
    owner = reg(client, "owner@example.com")
    member = reg(client, "m@example.com")
    cid = _solo_community(client, owner)
    befriend(client, owner, "owner@example.com", member, "m@example.com")
    member_id = uid(client, owner, "m@example.com")
    client.post(
        f"/community/{cid}/invite",
        json={"invitee_id": member_id},
        headers=auth_header(owner),
    )
    invite_id = client.get("/community/invites", headers=auth_header(member)).json()[0]["id"]
    client.post(f"/community/invite/{invite_id}/accept", headers=auth_header(member))

    log_a_meal(client, owner)
    post_id = _shared_post(client, owner, cid)
    client.post(f"/feed/{post_id}/react", json={"emoji": "👏"}, headers=auth_header(member))

    feed = client.get(f"/feed/{cid}", headers=auth_header(member)).json()
    assert len(feed) == 1
    assert feed[0]["author"]["handle"] == "owner@example.com"
    assert feed[0]["reactions"]["counts"]["👏"] == 1
    assert feed[0]["reactions"]["my_reaction"] == "👏"
