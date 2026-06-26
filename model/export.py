"""Export the trained Keras model to ONNX under versions/model_vN/.

Converts the checkpoint from train.py to ONNX so the backend can serve it with
onnxruntime alone — no TensorFlow at inference time. Each export lands in a new,
immutable versions/model_vN/ directory (never overwrites an older one).

Inputs (model/artifacts/, produced by train.py):
    dish_classifier.keras, class_names.json, metrics.json

Outputs (model/versions/model_vN/):
    model.onnx       -- the inference graph (preprocessing baked in)
    class_names.json -- labels in prediction-index order
    metadata.json    -- classes, input contract, metrics, export date

The input contract recorded in metadata.json is the backend's source of truth:
    float32 RGB image, shape [N, 224, 224, 3] (NHWC), pixels in [0, 255].
    Preprocessing (-> [-1, 1]) is INSIDE the graph; do not scale pixels first.

Run:
    python model/export.py            # auto-picks the next version number
    python model/export.py --opset 13
"""

from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

import tensorflow as tf
import tf2onnx
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--opset", type=int, default=13, help="ONNX opset version")
    args = parser.parse_args()

    model_path = ARTIFACTS_DIR / "dish_classifier.keras"
    class_names_path = ARTIFACTS_DIR / "class_names.json"
    if not model_path.exists() or not class_names_path.exists():
        raise SystemExit(
            f"Missing artifacts in {ARTIFACTS_DIR}. Run train.py first."
        )

    class_names = json.loads(class_names_path.read_text(encoding="utf-8"))
    metrics = {}
    metrics_path = ARTIFACTS_DIR / "metrics.json"
    if metrics_path.exists():
        metrics = json.loads(metrics_path.read_text(encoding="utf-8"))

    print(f"Loading {model_path} ...")
    model = keras.models.load_model(model_path)

    out_dir = next_version_dir()
    out_dir.mkdir(parents=True, exist_ok=False)
    onnx_path = out_dir / "model.onnx"

    # Fix the spatial dims, keep the batch axis dynamic (None).
    input_signature = [
        tf.TensorSpec([None, IMG_SIZE, IMG_SIZE, 3], tf.float32, name="input")
    ]
    print(f"Converting to ONNX (opset {args.opset}) ...")
    tf2onnx.convert.from_keras(
        model,
        input_signature=input_signature,
        opset=args.opset,
        output_path=str(onnx_path),
    )

    (out_dir / "class_names.json").write_text(
        json.dumps(class_names, indent=2), encoding="utf-8"
    )
    metadata = {
        "version": out_dir.name,
        "exported_on": date.today().isoformat(),
        "framework": f"onnx (opset {args.opset})",
        "classes": class_names,
        "num_classes": len(class_names),
        "input": {
            "name": "input",
            "shape": [None, IMG_SIZE, IMG_SIZE, 3],
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

    print(f"Exported {onnx_path}")
    print(f"Wrote class_names.json + metadata.json to {out_dir}")
    print(
        "Next: point the backend at this version and add a real ModelBackend in "
        "backend/app/core/model_backend.py."
    )


if __name__ == "__main__":
    main()
