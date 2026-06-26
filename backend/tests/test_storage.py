"""LocalDiskStorage: save/get/delete round trip and path-traversal guard."""

import pytest

from app.storage.local import LocalDiskStorage


def test_save_get_delete_roundtrip(tmp_path):
    storage = LocalDiskStorage(tmp_path)
    path = storage.save(b"image-bytes", "meal.jpg")
    assert path == "meals/meal.jpg"  # relative path string, what the DB will store
    assert storage.get(path) == b"image-bytes"
    storage.delete(path)
    with pytest.raises(FileNotFoundError):
        storage.get(path)


def test_namespace_separates_targets(tmp_path):
    storage = LocalDiskStorage(tmp_path)
    path = storage.save(b"x", "meal.jpg", namespace="training")
    assert path == "training/meal.jpg"


def test_path_traversal_rejected(tmp_path):
    storage = LocalDiskStorage(tmp_path)
    with pytest.raises(ValueError):
        storage.get("../../secrets.txt")
