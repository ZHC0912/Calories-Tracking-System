# Model Training Ground

ML training lives here, **separate from the backend**. The backend never
imports from this directory — it only loads exported, versioned model files
through the `ModelBackend` interface (`backend/app/core/model_backend.py`).

## The train → export → version → swap flow

1. **Train** (`train.py`): transfer-learn an EfficientNet classifier on dish
   images under `datasets/`. Coverage grows in waves:
   SE Asian dishes → broader Asian → Western.
2. **Export** (`export.py`): convert the trained checkpoint to an inference
   format (ONNX or TFLite) so the backend needs no training framework.
3. **Version**: drop the exported file into `versions/` as `model_v1/`,
   `model_v2/`, … with a small metadata file (classes, date, metrics).
   Versions are immutable — never overwrite an old one.
4. **Swap**: point the backend at the new version via config and implement /
   select the real backend in `get_model_backend()`. No other backend code
   changes. Roll back by pointing at the previous version.

## Future training data

A later phase will (opt-in per user, EXIF-stripped, stored separately from
personal history) collect user meal photos into `datasets/` to improve the
model over time.

`train.py` and `export.py` are skeletons in Phase 1 — the backend ships with
a stub model until the first real version lands.
