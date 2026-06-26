"""Auth flow: register -> login -> reach a protected route with the token."""

from tests.conftest import auth_header, register_and_login


def test_register_returns_token(client):
    resp = client.post(
        "/auth/register", json={"email": "a@example.com", "password": "password123"}
    )
    assert resp.status_code == 201
    assert resp.json()["token_type"] == "bearer"
    assert resp.json()["access_token"]


def test_duplicate_email_rejected(client):
    client.post("/auth/register", json={"email": "a@example.com", "password": "password123"})
    resp = client.post(
        "/auth/register", json={"email": "a@example.com", "password": "password123"}
    )
    assert resp.status_code == 409


def test_login_with_correct_password(client):
    register_and_login(client, "b@example.com", "password123")
    resp = client.post(
        "/auth/login", json={"email": "b@example.com", "password": "password123"}
    )
    assert resp.status_code == 200
    assert resp.json()["access_token"]


def test_login_with_wrong_password_rejected(client):
    register_and_login(client, "c@example.com", "password123")
    resp = client.post(
        "/auth/login", json={"email": "c@example.com", "password": "wrongpass1"}
    )
    assert resp.status_code == 401


def test_protected_route_requires_token(client):
    assert client.get("/profile").status_code in (401, 403)


def test_protected_route_with_token(client):
    token = register_and_login(client)
    resp = client.get("/profile", headers=auth_header(token))
    assert resp.status_code == 200
    body = resp.json()
    assert body["email"] == "user@example.com"
    assert "not medical advice" in body["note"].lower()


def test_password_never_echoed(client):
    resp = client.post(
        "/auth/register", json={"email": "d@example.com", "password": "password123"}
    )
    assert "password123" not in resp.text
