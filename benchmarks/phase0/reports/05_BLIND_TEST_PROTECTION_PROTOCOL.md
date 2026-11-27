# 05 — Blind Test Protection Protocol

Implementation: `benchmarks/phase0/blind_protection.py`.

## Structural Guarantees
1. **Label Stripping (`strip_blind_labels`):** Stage B execution consumes `stage_b_inputs_blind.jsonl` containing ONLY audio path, ID, and technical signal headers; `target_word`, `expected_outcome`, `reference_ipa`, and `actual_pronounced_phoneme` reside ONLY in `D:\YasserML\manifests\blind_vault_external\stage_b_labels_VAULT_ONLY.json` outside the Git repo and inference process.
2. **Immutable Freeze Lock (`BlindFreezeLock`):** Cryptographically hashes Stage A manifest, Stage B blind inputs, Stage B label vault, active model SHA-256s, threshold config, and preprocessing config before Stage B authorization.
3. **Zero Synthetic Rule:** `strip_blind_labels` throws `BlindAuthorizationError` immediately if any `controlled_synthetic` entry attempts to enter Stage B.
4. **Signature Firewall (`verify_blind_inference_signature`):** Uses Python runtime inspection (`inspect.signature`) to abort execution if an inference entrypoint exposes `target_word`, `expected_phonemes`, `label`, `hint`, or `oracle`.
5. **Post-Freeze Drift Lock (`authorize_blind_execution`):** Any post-freeze change to thresholds, preprocessing, model hashes, or Stage B manifest aborts execution immediately.
