"""Swappable file-storage interface.

Local disk in dev, a cloud bucket later — callers never know which. The
database only ever stores the path string returned by save(), never bytes.

The `namespace` parameter exists so a later phase can write to additional
targets without changing call sites — e.g. an OPT-IN, EXIF-stripped training
copy of meal images saved under a separate "training" namespace, kept apart
from the user's personal history. (Not implemented in Phase 1 — interface
shape only.)
"""

from abc import ABC, abstractmethod


class StorageBackend(ABC):
    """Interface every storage backend must implement."""

    @abstractmethod
    def save(self, file_bytes: bytes, name: str, namespace: str = "meals") -> str:
        """Store bytes under a namespace. Returns the path string to persist."""

    @abstractmethod
    def get(self, path: str) -> bytes:
        """Read back the bytes for a path returned by save()."""

    @abstractmethod
    def delete(self, path: str) -> None:
        """Remove the file at a path returned by save()."""
