"""Swappable dish-recognition backend.

The real model runs SERVER-SIDE behind this interface so it can be retrained
and hot-swapped (versioned files under model/versions/) without touching the
rest of the backend. StubBackend is the no-ML default; TFLiteBackend loads a
trained model.tflite exported by model/export.py.

Heavy/optional deps (the TFLite runtime, numpy, Pillow) are imported lazily
inside TFLiteBackend so the stub path and the rest of the app run without them.
"""

import io
import json
import threading
from abc import ABC, abstractmethod
from functools import lru_cache
from pathlib import Path

from ..schemas.analysis import FoodItem
from . import dishes
from .caption import parse_caption

# Default location of the exported model: <repo>/model/versions/model_v1.
# model_backend.py is at <repo>/backend/app/core/, so parents[3] is <repo>.
_DEFAULT_MODEL_DIR = Path(__file__).resolve().parents[3] / "model" / "versions" / "model_v1"


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


def _load_interpreter_cls():
    """Return a TFLite Interpreter class, preferring lightweight runtimes."""
    try:
        from ai_edge_litert.interpreter import Interpreter

        return Interpreter
    except ImportError:
        pass
    try:
        from tflite_runtime.interpreter import Interpreter

        return Interpreter
    except ImportError:
        pass
    try:
        from tensorflow.lite import Interpreter

        return Interpreter
    except ImportError as exc:  # pragma: no cover - only when nothing is installed
        raise ImportError(
            "No TFLite runtime found. Install one: pip install ai-edge-litert"
        ) from exc


class TFLiteBackend(ModelBackend):
    """Serves a trained model.tflite (MobileNetV2 dish classifier).

    Loads <model_dir>/model.tflite and <model_dir>/class_names.json. The model
    bakes its own preprocessing (Rescaling to [-1, 1]), so we feed a raw float32
    RGB image in [0, 255] resized to 224x224 — the SAME pipeline training used
    (see model/train.py). A prediction index maps to class_names[idx], then
    dishes.LABEL_TO_DISH to a catalog dish the rest of the pipeline understands.
    """

    IMG_SIZE = 224

    def __init__(self, model_dir: str | Path | None = None):
        self._model_dir = Path(model_dir) if model_dir else _DEFAULT_MODEL_DIR
        self._interpreter = None
        self._class_names: list[str] = []
        self._input_index: int | None = None
        self._output_index: int | None = None
        self._lock = threading.Lock()  # TFLite interpreters aren't reentrant

    def _ensure_loaded(self) -> None:
        if self._interpreter is not None:
            return
        model_path = self._model_dir / "model.tflite"
        names_path = self._model_dir / "class_names.json"
        if not model_path.exists():
            raise FileNotFoundError(
                f"TFLite model not found at {model_path}. Run model/train.py + "
                "export.py and place the version dir there, or set MODEL_DIR."
            )
        self._class_names = json.loads(names_path.read_text(encoding="utf-8"))

        interpreter_cls = _load_interpreter_cls()
        interpreter = interpreter_cls(model_path=str(model_path))
        interpreter.allocate_tensors()
        self._interpreter = interpreter
        self._input_index = interpreter.get_input_details()[0]["index"]
        self._output_index = interpreter.get_output_details()[0]["index"]

    def _preprocess(self, image_bytes: bytes):
        import numpy as np
        from PIL import Image

        # BILINEAR + stretch-to-square matches tf.image.resize in training.
        img = (
            Image.open(io.BytesIO(image_bytes))
            .convert("RGB")
            .resize((self.IMG_SIZE, self.IMG_SIZE), Image.BILINEAR)
        )
        arr = np.asarray(img, dtype=np.float32)  # [224, 224, 3] in [0, 255]
        return arr[np.newaxis, ...]  # add batch axis -> [1, 224, 224, 3]

    def analyze(self, image_bytes: bytes, caption: str | None = None) -> list[FoodItem]:
        # caption is intentionally unused for recognition — the image decides the
        # dish; the /analyze pipeline still uses the caption for portion grams.
        import numpy as np

        self._ensure_loaded()
        batch = self._preprocess(image_bytes)
        with self._lock:
            self._interpreter.set_tensor(self._input_index, batch)
            self._interpreter.invoke()
            probs = self._interpreter.get_tensor(self._output_index)[0]  # softmax

        idx = int(np.argmax(probs))
        label = self._class_names[idx]
        dish = dishes.LABEL_TO_DISH.get(label, label)
        return [FoodItem(dish=dish, confidence=float(probs[idx]))]


@lru_cache(maxsize=None)
def get_model_backend(name: str = "stub", model_dir: str | None = None) -> ModelBackend:
    """Factory selected via config (MODEL_BACKEND / MODEL_DIR env vars).

    Cached so a backend (and its loaded model) is built once and reused across
    requests. Add new backends here; no other backend code changes.
    """
    if name == "stub":
        return StubBackend()
    if name == "tflite":
        return TFLiteBackend(model_dir)
    raise ValueError(
        f"Unknown model backend {name!r}. Register new backends in get_model_backend()."
    )
