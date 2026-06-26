"""Local-disk storage backend for development."""

from pathlib import Path

from .base import StorageBackend


class LocalDiskStorage(StorageBackend):
    """Writes files under a configurable root directory (STORAGE_DIR)."""

    def __init__(self, root_dir: str | Path):
        self.root = Path(root_dir)

    def save(self, file_bytes: bytes, name: str, namespace: str = "meals") -> str:
        target = self._resolve(f"{namespace}/{name}")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(file_bytes)
        # Return the path relative to the root: that string is what gets
        # persisted, so swapping to a bucket backend later won't break stored
        # references.
        return target.relative_to(self.root.resolve()).as_posix()

    def get(self, path: str) -> bytes:
        return self._resolve(path).read_bytes()

    def delete(self, path: str) -> None:
        target = self._resolve(path)
        if target.exists():
            target.unlink()

    def _resolve(self, path: str) -> Path:
        """Resolve a relative path under root, refusing path traversal."""
        root = self.root.resolve()
        target = (root / path).resolve()
        if not target.is_relative_to(root):
            raise ValueError(f"Path {path!r} escapes the storage root.")
        return target
