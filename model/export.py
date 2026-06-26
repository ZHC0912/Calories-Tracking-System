"""Export the trained Keras model to TFLite under versions/model_vN/.

Converts the checkpoint from train.py to a TFLite flatbuffer so the backend can
serve it with a lightweight runtime (ai-edge-litert) — no full TensorFlow at
inference time. TFLite conversion is built into TensorFlow, so it tracks
whatever TF version is installed (unlike third-party ONNX tooling). Each export
lands in a new, immutable versions/model_vN/ directory (never overwrites older).

Inputs (model/artifacts/, produced by train.py):
    dish_classifier.keras, class_names.json, metrics.json

Outputs (model/versions/model_vN/):
    model.tflite     -- the inference graph (preprocessing baked in)
    class_names.json -- labels in prediction-index order
    metadata.json    -- classes, input contract, metrics, export date

The input contract recorded in metadata.json is the backend's source of truth:
    float32 RGB image, shape [1, 224, 224, 3] (NHWC), pixels in [0, 255].
    Preprocessing (-> [-1, 1]) is INSIDE the graph; do not scale pixels first.

Run:
    python model/export.py
"""

from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

import tensorflow as tf
from tensorflow import keras

HERE = Path(__file__).resolve().parent
ARTIFACTS_DIR = HERE / "artifacts"
VERSIONS_DIR = HERE / "versions"

IMG_SIZE = 224


def next_version_dir() -> Path:
    """Return the next free versions/model_vN/ (N = max existing + 1)."""
    VERSIONS_DIR.mkdir(parents=True, exist_ok=True)
    existing = [
        int(p.name[len("model_v") :])
        for p in VERSIONS_DIR.glob("model_v*")
        if p.is_dir() and p.name[len("model_v") :].isdigit()
    ]
    n = (max(existing) + 1) if existing else 1
    return VERSIONS_DIR / f"model_v{n}"


def main() -> None:
    argparse.ArgumentParser(description=__doc__).parse_args()

    model_path = ARTIFACTS_DIR / "dish_classifier.keras"
    class_names_path = ARTIFACTS_DIR / "class_names.json"
    if not model_path.exists() or not class_names_path.exists():
        raise SystemExit(f"Missing artifacts in {ARTIFACTS_DIR}. Run train.py first.")

    class_names = json.loads(class_names_path.read_text(encoding="utf-8"))
    metrics = {}
    metrics_path = ARTIFACTS_DIR / "metrics.json"
    if metrics_path.exists():
        metrics = json.loads(metrics_path.read_text(encoding="utf-8"))

    print(f"Loading {model_path} ...")
    model = keras.models.load_model(model_path)

    out_dir = next_version_dir()
    out_dir.mkdir(parents=True, exist_ok=False)
    tflite_path = out_dir / "model.tflite"

    print("Converting to TFLite ...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_bytes = converter.convert()
    tflite_path.write_bytes(tflite_bytes)

    (out_dir / "class_names.json").write_text(
        json.dumps(class_names, indent=2), encoding="utf-8"
    )
    metadata = {
        "version": out_dir.name,
        "exported_on": date.today().isoformat(),
        "framework": "tflite",
        "classes": class_names,
        "num_classes": len(class_names),
        "input": {
            "name": "input",
            "shape": [1, IMG_SIZE, IMG_SIZE, 3],
            "layout": "NHWC",
            "dtype": "float32",
            "color": "RGB",
            "value_range": [0, 255],
            "preprocessing": (
                "baked into graph (Rescaling to [-1, 1] == "
                "mobilenet_v2.preprocess_input); do NOT scale pixels before inference"
            ),
        },
        "output": {
            "activation": "softmax",
            "note": "argmax index -> class_names[index] -> LABEL_TO_DISH (backend)",
        },
        "metrics": metrics,
    }
    (out_dir / "metadata.json").write_text(
        json.dumps(metadata, indent=2), encoding="utf-8"
    )

    size_mb = tflite_path.stat().st_size / 1e6
    print(f"Exported {tflite_path} ({size_mb:.1f} MB)")
    print(f"Wrote class_names.json + metadata.json to {out_dir}")
    print(
        "Next: point the backend at this version and add a real ModelBackend in "
        "backend/app/core/model_backend.py (serve with ai-edge-litert)."
    )


if __name__ == "__main__":
    main()
