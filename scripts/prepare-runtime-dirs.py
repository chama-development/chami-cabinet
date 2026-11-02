"""One-shot ownership migration for the three application bind mounts only."""
import os
from pathlib import Path

RUNTIME_UID = RUNTIME_GID = 10001
RUNTIME_DIRS = ("assets", "logs", "backups")


def prepare(root: Path = Path("/opt/remnashop")) -> None:
    for name in RUNTIME_DIRS:
        directory = root / name
        if directory.is_symlink():
            raise RuntimeError(f"refusing symlink mount: {directory}")
        directory.mkdir(parents=True, exist_ok=True)
        # Never follow symlinks out of an application volume.
        for parent, dirs, files in os.walk(directory, followlinks=False):
            os.chown(parent, RUNTIME_UID, RUNTIME_GID, follow_symlinks=False)
            for child in dirs + files:
                os.chown(Path(parent) / child, RUNTIME_UID, RUNTIME_GID, follow_symlinks=False)


if __name__ == "__main__":
    prepare()
