"""Storage and workspace configuration keeping ML artifacts off C: drive."""

from __future__ import annotations

import json
import os
import shutil
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
PHASE0_DIR = Path(__file__).resolve().parent
DEFAULT_ML_ROOT = Path(os.environ.get("YASSER_ML_ROOT", r"D:\YasserML"))


@dataclass(frozen=True)
class YasserWorkspaceConfig:
    """Configurable paths for non-C: ML storage and repo-local governance files."""

    ml_root: Path = DEFAULT_ML_ROOT
    repo_root: Path = REPO_ROOT
    min_system_drive_free_gb: float = 5.0
    min_ml_drive_free_gb: float = 20.0

    @property
    def models_dir(self) -> Path:
        return self.ml_root / "models"

    @property
    def datasets_raw_dir(self) -> Path:
        return self.ml_root / "datasets" / "raw"

    @property
    def datasets_processed_dir(self) -> Path:
        return self.ml_root / "datasets" / "processed"

    @property
    def manifests_dir(self) -> Path:
        return self.ml_root / "manifests"

    @property
    def cache_dir(self) -> Path:
        return self.ml_root / "cache"

    @property
    def hf_home(self) -> Path:
        return self.cache_dir / "huggingface"

    @property
    def torch_home(self) -> Path:
        return self.cache_dir / "torch"

    @property
    def pip_cache_dir(self) -> Path:
        return self.cache_dir / "pip"

    @property
    def reports_dir(self) -> Path:
        return self.ml_root / "reports"

    @property
    def checkpoints_dir(self) -> Path:
        return self.ml_root / "checkpoints"

    @property
    def quarantine_dir(self) -> Path:
        return self.ml_root / "quarantine"

    @property
    def blind_vault_dir(self) -> Path:
        return self.ml_root / "manifests" / "blind_vault_external"

    def all_directories(self) -> list[Path]:
        return [
            self.ml_root,
            self.models_dir,
            self.datasets_raw_dir,
            self.datasets_processed_dir,
            self.manifests_dir,
            self.cache_dir,
            self.hf_home,
            self.torch_home,
            self.pip_cache_dir,
            self.reports_dir,
            self.checkpoints_dir,
            self.quarantine_dir,
            self.blind_vault_dir,
        ]

    def env_overrides(self) -> dict[str, str]:
        """Environment variables routing ML caches off C: during process execution."""
        return {
            "YASSER_ML_ROOT": str(self.ml_root),
            "HF_HOME": str(self.hf_home),
            "HF_DATASETS_CACHE": str(self.hf_home / "datasets"),
            "HUGGINGFACE_HUB_CACHE": str(self.hf_home / "hub"),
            "TORCH_HOME": str(self.torch_home),
            "PIP_CACHE_DIR": str(self.pip_cache_dir),
            "TMPDIR": str(self.cache_dir / "tmp"),
        }

    def to_json_dict(self) -> dict[str, Any]:
        return {
            "schema_version": "1.0.0",
            "updated_utc": datetime.now(timezone.utc).isoformat(),
            "repo_root": str(self.repo_root),
            "ml_root": str(self.ml_root),
            "directories": {
                "models": str(self.models_dir),
                "datasets_raw": str(self.datasets_raw_dir),
                "datasets_processed": str(self.datasets_processed_dir),
                "manifests": str(self.manifests_dir),
                "cache": str(self.cache_dir),
                "reports": str(self.reports_dir),
                "checkpoints": str(self.checkpoints_dir),
                "quarantine": str(self.quarantine_dir),
                "blind_vault_external": str(self.blind_vault_dir),
            },
            "process_env_recommendations": self.env_overrides(),
            "thresholds": {
                "min_system_drive_free_gb": self.min_system_drive_free_gb,
                "min_ml_drive_free_gb": self.min_ml_drive_free_gb,
            },
            "git_policy": {
                "raw_audio_committed": False,
                "large_weights_committed_outside_bundled_assets": False,
                "blind_stage_b_labels_stored_outside_git": True,
            },
        }


def get_disk_usage_gb(path_or_drive: str | Path) -> dict[str, Any]:
    """Return total/used/free GB for a drive or directory if mounted."""
    target = Path(path_or_drive)
    probe = target
    while not probe.exists() and probe.parent != probe:
        probe = probe.parent
    if not probe.exists():
        return {"path": str(target), "exists": False}
    usage = shutil.disk_usage(probe)
    return {
        "path": str(target),
        "probe_mount": str(probe),
        "exists": True,
        "total_gb": round(usage.total / (1024**3), 2),
        "used_gb": round(usage.used / (1024**3), 2),
        "free_gb": round(usage.free / (1024**3), 2),
    }


def get_storage_report(config: YasserWorkspaceConfig | None = None) -> dict[str, Any]:
    """Inspect C:, D:, and E: plus workspace paths with low-disk warnings."""
    cfg = config or YasserWorkspaceConfig()
    c_drive = get_disk_usage_gb("C:\\")
    d_drive = get_disk_usage_gb("D:\\")
    e_drive = get_disk_usage_gb("E:\\")
    warnings: list[str] = []
    if c_drive.get("exists") and c_drive.get("free_gb", 0.0) < cfg.min_system_drive_free_gb:
        warnings.append(
            f"CRITICAL_C_DRIVE_LOW: C: has only {c_drive['free_gb']} GB free "
            f"(< {cfg.min_system_drive_free_gb} GB policy minimum). Block C: installs/caches."
        )
    return {
        "checked_utc": datetime.now(timezone.utc).isoformat(),
        "drives": {"C": c_drive, "D": d_drive, "E": e_drive},
        "ml_root": str(cfg.ml_root),
        "ml_root_exists": cfg.ml_root.exists(),
        "warnings": warnings,
    }


def ensure_workspace(config: YasserWorkspaceConfig | None = None) -> dict[str, Any]:
    """Create D:\\YasserML subdirectories cleanly and persist workspace_config.json."""
    cfg = config or YasserWorkspaceConfig()
    for folder in cfg.all_directories():
        folder.mkdir(parents=True, exist_ok=True)
    (cfg.cache_dir / "tmp").mkdir(parents=True, exist_ok=True)
    config_file = cfg.ml_root / "workspace_config.json"
    config_file.write_text(json.dumps(cfg.to_json_dict(), indent=2), encoding="utf-8")
    return {
        "config_file": str(config_file),
        "directories_created": [str(p) for p in cfg.all_directories()],
        "storage_report": get_storage_report(cfg),
    }


if __name__ == "__main__":
    print(json.dumps(ensure_workspace(), indent=2))
