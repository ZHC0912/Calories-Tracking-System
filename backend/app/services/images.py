"""Privacy utility: strip EXIF metadata from meal images before storage.

EXIF can carry GPS coordinates, device serials and capture timestamps. We strip
it from EVERY stored meal image (not just opt-in training copies) by decoding
the pixels and re-encoding without any metadata.
"""

import io

from PIL import Image


def strip_exif(image_bytes: bytes) -> bytes:
    """Return the image re-encoded with all metadata removed.

    Falls back to the original bytes if the data isn't a decodable image, so a
    logging request never fails purely because of an odd upload.
    """
    try:
        with Image.open(io.BytesIO(image_bytes)) as img:
            fmt = img.format or "JPEG"
            img.load()
            # Rebuild from raw pixels so no EXIF/ICC/XMP metadata carries over.
            clean = Image.frombytes(img.mode, img.size, img.tobytes())
            out = io.BytesIO()
            clean.save(out, format=fmt)
            return out.getvalue()
    except Exception:
        return image_bytes
