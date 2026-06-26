"""Tests for the dish-recognition backends (stub + tflite)."""

import io
import json
from pathlib import Path

import pytest

from app.core import dishes
from app.core.model_backend import StubBackend, TFLiteBackend, get_model_backend

MODEL_DIR = Path(__file__).resolve().parents[2] / "model" / "versions" / "model_v1"
MODEL_FILE = MODEL_DIR / "model.tflite"
NAMES_FILE = MODEL_DIR / "class_names.json"


def test_factory_returns_requested_backend():
    assert isinstance(get_model_backend("stub"), StubBackend)
    assert isinstance(get_model_backend("tflite"), TFLiteBackend)


def test_factory_rejects_unknown_backend():
    with pytest.raises(ValueError):
        get_model_backend("does-not-exist")


def test_exported_labels_are_all_wired_to_dishes():
    """Every label a trained model can emit must resolve to a catalog dish."""
    if not NAMES_FILE.exists():
        pytest.skip("no exported model present")
    class_names = json.loads(NAMES_FILE.read_text(encoding="utf-8"))
    for label in class_names:
        assert label in dishes.LABEL_TO_DISH, f"{label!r} missing from LABEL_TO_DISH"
        assert dishes.get_dish(dishes.LABEL_TO_DISH[label]) is not None


@pytest.mark.skipif(not MODEL_FILE.exists(), reason="no trained model.tflite present")
def test_tflite_backend_classifies_an_image():
    from PIL import Image  # Pillow is a hard dependency

    backend = TFLiteBackend(MODEL_DIR)
    buf = io.BytesIO()
    Image.new("RGB", (320, 240), (130, 90, 60)).save(buf, format="JPEG")
    try:
        items = backend.analyze(buf.getvalue())
    except ImportError as exc:  # no numpy / TFLite runtime installed
        pytest.skip(f"TFLite runtime not installed: {exc}")

    assert len(items) == 1
    item = items[0]
    assert 0.0 <= item.confidence <= 1.0
    # predicted dish must resolve to a real catalog entry so grams/nutrients work
    assert dishes.get_dish(item.dish) is not None
