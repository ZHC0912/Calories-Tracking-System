"""Swappable dish-recognition backend.

The real model runs SERVER-SIDE behind this interface so it can be retrained
and hot-swapped (versioned files under model/versions/) without touching the
rest of the backend. Phase 1 ships only StubBackend; a real backend (e.g.
ONNX EfficientNet) registers itself in get_model_backend() later.
"""

from abc import ABC, abstractmethod

from ..schemas.analysis import FoodItem
from . import dishes
from .caption import parse_caption


class ModelBackend(ABC):
    """Interface every dish-recognition model must implement."""

    @abstractmethod
    def analyze(self, image_bytes: bytes, caption: str | None = None) -> list[FoodItem]:
        """Recognize dishes in an image. Returns items with dish + confidence
        set; grams/nutrients are filled in later by the analysis pipeline."""


class StubBackend(ModelBackend):
    """Fake model for development and tests. Ignores image content.

    Deterministic: picks dishes from the supported list based on the image
    byte length, or prefers dishes named in the caption when one is given.
    """

    def analyze(self, image_bytes: bytes, caption: str | None = None) -> list[FoodItem]:
        if caption:
            named = [
                item.name
                for item in parse_caption(caption)
                if dishes.get_dish(item.name) is not None
            ]
            if named:
                return [FoodItem(dish=name, confidence=0.95) for name in named[:2]]

        supported = dishes.SUPPORTED_DISHES
        primary = supported[len(image_bytes) % len(supported)]
        items = [FoodItem(dish=primary, confidence=0.62)]
        if len(image_bytes) % 2 == 0:
            secondary = supported[(len(image_bytes) + 1) % len(supported)]
            items.append(FoodItem(dish=secondary, confidence=0.31))
        return items


def get_model_backend(name: str = "stub") -> ModelBackend:
    """Factory selected via config (MODEL_BACKEND env var).

    Extension point: when a real model lands, add e.g.
        if name == "onnx": return OnnxBackend(model_path=...)
    """
    if name == "stub":
        return StubBackend()
    raise ValueError(
        f"Unknown model backend {name!r}. Register new backends in get_model_backend()."
    )
