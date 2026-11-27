# 10 — Yasser AI Lab Governance Extension Design

Extended existing Developer AI Lab without duplicating screens:
- **Route & Entry:** Added Card #12 (`AppRoutes.aiLabGovernance = '/ai-lab/governance'`) in `AiLabHubView` plus an AppBar Governance shortcut in `ModelManagerView`.
- **View (`lib/features/ai_lab/views/phase0_governance_view.dart`):** 3 tabs (`النماذج والسجل`, `البيانات والأعمى`, `التسرب والاختبارات`) powered by `Phase0GovernanceService` (`lib/core/ai/phase0_governance_service.dart`).
- **Sanitized Runtime Asset (`assets/ai_governance/phase0_summary.json`):** Contains metadata/counts/reconciliation ONLY and asserts `blind_labels_included == false` (`StateError` raised if tampered).
- **Verified by Flutter Tests (`test/core/ai/phase0_governance_test.dart`):** Manifest checksum integrity, blind-label absence check, and full 3-tab widget render test.
