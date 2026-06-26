"""Train a dish classifier via MobileNetV2 transfer learning.

Standalone training script (Colab or local GPU). The backend NEVER imports this
module — it only loads the exported ONNX file produced later by export.py.

Flow:
    1. Download malaysia-food-11 with kagglehub (or use --data-dir).
    2. Build train/val/test datasets (80/10/10) from the class folders.
    3. Capture class_names in dataset order and check them against the labels
       the backend expects (LABEL_TO_DISH in backend/app/core/dishes.py).
    4. Transfer-learn: freeze MobileNetV2, train the head, then fine-tune the
       top layers at a low learning rate.
    5. Evaluate on the held-out test set and save artifacts for export.py.

Outputs (model/artifacts/):
    dish_classifier.keras  -- the trained model
    class_names.json       -- labels in prediction-index order (export reads this)
    metrics.json           -- test loss/accuracy + training config

IMPORTANT — keep training and inference preprocessing identical. Preprocessing
is baked INTO the model (a Rescaling layer == mobilenet_v2.preprocess_input), so
the exported graph expects a raw float32 RGB image in [0, 255], NHWC, 224x224.
The backend only has to decode + resize; it must NOT pre-scale pixels.

Run:
    python model/train.py                 # downloads the dataset, trains
    python model/train.py --data-dir ...  # use an already-downloaded copy
"""

from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

HERE = Path(__file__).resolve().parent
ARTIFACTS_DIR = HERE / "artifacts"

DATASET_SLUG = "karkengchan/malaysia-food-11"

# The 11 class folders in malaysia-food-11 — these ARE the model's output labels.
# They MUST match the keys of LABEL_TO_DISH in backend/app/core/dishes.py, which
# turns a predicted label into a portion + USDA query. If the dataset's folders
# differ, the run warns so you can reconcile the two before wiring the model in.
EXPECTED_LABELS = {
    "fish_and_chips",
    "fried_noodles",
    "fried_rice",
    "hamburger",
    "kaya_toast",
    "laksa",
    "mixed_rice",
    "nasi_lemak",
    "popiah",
    "roti_canai",
    "satay",
}

AUTOTUNE = tf.data.AUTOTUNE


def locate_dataset_dir(root: Path) -> Path:
    """Find the directory whose subfolders are the dish classes.

    kagglehub may nest the images a few levels deep, so search the tree for the
    directory whose immediate subfolders best match EXPECTED_LABELS.
    """
    candidates = [root, *(p for p in root.rglob("*") if p.is_dir())]
    best: Path | None = None
    best_score = 0
    for d in candidates:
        subdirs = {c.name for c in d.iterdir() if c.is_dir()}
        score = len(subdirs & EXPECTED_LABELS)
        if score > best_score:
            best, best_score = d, score
    if best is None:
        raise SystemExit(
            f"No class folders found under {root}. Pass --data-dir explicitly."
        )
    return best


def build_datasets(data_dir: Path, img_size: int, batch_size: int, seed: int):
    """Return (train_ds, val_ds, test_ds, class_names) with an 80/10/10 split.

    image_dataset_from_directory only does a 2-way split, so we carve the test
    set out of the validation half. class_names is captured BEFORE any map() so
    the labels stay attached to their integer indices.
    """
    train_ds = keras.utils.image_dataset_from_directory(
        data_dir,
        validation_split=0.2,
        subset="training",
        seed=seed,
        image_size=(img_size, img_size),
        batch_size=batch_size,
        label_mode="int",
    )
    class_names = train_ds.class_names

    val_full = keras.utils.image_dataset_from_directory(
        data_dir,
        validation_split=0.2,
        subset="validation",
        seed=seed,
        image_size=(img_size, img_size),
        batch_size=batch_size,
        label_mode="int",
    )
    # Split the 20% validation half into 10% val / 10% test.
    val_batches = val_full.cardinality()
    test_ds = val_full.take(val_batches // 2)
    val_ds = val_full.skip(val_batches // 2)

    return train_ds, val_ds, test_ds, class_names


def build_model(num_classes: int, img_size: int):
    """MobileNetV2 backbone + classification head.

    Returns (model, base) so the caller can unfreeze the base for fine-tuning.
    The Rescaling layer maps [0, 255] -> [-1, 1], exactly what
    mobilenet_v2.preprocess_input does — baking it in keeps train/serve parity.
    """
    base = keras.applications.MobileNetV2(
        input_shape=(img_size, img_size, 3), include_top=False, weights="imagenet"
    )
    base.trainable = False

    inputs = keras.Input(shape=(img_size, img_size, 3))
    x = layers.Rescaling(1.0 / 127.5, offset=-1.0)(inputs)
    x = base(x, training=False)  # keep BatchNorm in inference mode (TL pattern)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    model = keras.Model(inputs, outputs)
    return model, base


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", default=DATASET_SLUG, help="kagglehub slug")
    parser.add_argument(
        "--data-dir", default=None, help="skip download; use this image root"
    )
    parser.add_argument("--img-size", type=int, default=224)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--epochs-head", type=int, default=8)
    parser.add_argument("--epochs-finetune", type=int, default=5)
    parser.add_argument(
        "--fine-tune-layers",
        type=int,
        default=30,
        help="number of top backbone layers to unfreeze for fine-tuning",
    )
    parser.add_argument("--seed", type=int, default=123)
    args = parser.parse_args()

    # --- Locate the images -------------------------------------------------
    if args.data_dir:
        data_dir = Path(args.data_dir).expanduser().resolve()
    else:
        import kagglehub

        print(f"Downloading {args.dataset} via kagglehub ...")
        data_dir = Path(kagglehub.dataset_download(args.dataset))

    data_dir = locate_dataset_dir(data_dir)
    print(f"Using image root: {data_dir}")

    train_ds, val_ds, test_ds, class_names = build_datasets(
        data_dir, args.img_size, args.batch_size, args.seed
    )
    print(f"Classes ({len(class_names)}): {class_names}")

    # --- Sanity-check labels against what the backend expects --------------
    found = set(class_names)
    missing = EXPECTED_LABELS - found
    extra = found - EXPECTED_LABELS
    if missing or extra:
        print(
            "WARNING: dataset classes differ from EXPECTED_LABELS.\n"
            f"  missing (expected, not found): {sorted(missing)}\n"
            f"  extra (found, unexpected):     {sorted(extra)}\n"
            "  Reconcile these with LABEL_TO_DISH in backend/app/core/dishes.py."
        )

    # --- Augment + prefetch ------------------------------------------------
    augment = keras.Sequential(
        [
            layers.RandomFlip("horizontal"),
            layers.RandomRotation(0.1),
            layers.RandomZoom(0.1),
            layers.RandomContrast(0.1),
        ],
        name="augmentation",
    )
    train_ds = train_ds.map(
        lambda x, y: (augment(x, training=True), y), num_parallel_calls=AUTOTUNE
    )
    train_ds = train_ds.cache().prefetch(AUTOTUNE)
    val_ds = val_ds.cache().prefetch(AUTOTUNE)
    test_ds = test_ds.cache().prefetch(AUTOTUNE)

    # --- Stage 1: train the head (frozen backbone) -------------------------
    model, base = build_model(len(class_names), args.img_size)
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    print("Stage 1/2: training classification head (backbone frozen) ...")
    model.fit(train_ds, validation_data=val_ds, epochs=args.epochs_head)

    # --- Stage 2: fine-tune the top of the backbone ------------------------
    base.trainable = True
    for layer in base.layers[: -args.fine_tune_layers]:
        layer.trainable = False
    model.compile(
        optimizer=keras.optimizers.Adam(1e-5),  # low LR so we don't wreck features
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    print(f"Stage 2/2: fine-tuning top {args.fine_tune_layers} backbone layers ...")
    model.fit(train_ds, validation_data=val_ds, epochs=args.epochs_finetune)

    # --- Evaluate on the held-out test set ---------------------------------
    test_loss, test_acc = model.evaluate(test_ds)
    print(f"Test accuracy: {test_acc:.4f}  (loss {test_loss:.4f})")

    # --- Save artifacts for export.py --------------------------------------
    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    model_path = ARTIFACTS_DIR / "dish_classifier.keras"
    model.save(model_path)

    (ARTIFACTS_DIR / "class_names.json").write_text(
        json.dumps(class_names, indent=2), encoding="utf-8"
    )
    (ARTIFACTS_DIR / "metrics.json").write_text(
        json.dumps(
            {
                "test_accuracy": float(test_acc),
                "test_loss": float(test_loss),
                "num_classes": len(class_names),
                "trained_on": date.today().isoformat(),
                "dataset": args.dataset,
                "img_size": args.img_size,
                "epochs_head": args.epochs_head,
                "epochs_finetune": args.epochs_finetune,
                "fine_tune_layers": args.fine_tune_layers,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Saved model + class_names + metrics to {ARTIFACTS_DIR}")
    print("Next: python model/export.py  (converts to ONNX under versions/)")


if __name__ == "__main__":
    main()
