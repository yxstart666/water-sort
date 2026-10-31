# Color Pause / 彩瓶时光

Godot 4.7.2 Standard desktop playtest. The current version includes the approved fused home image, real energy, direction-locked pouring, settings/Pause fixes, restart-title alpha and the three corrected victory labels. Start breathing remains OFF as a safety fallback, not a claim that its animation has been smoothed.

## Run

First import: `godot --headless --editor --path . --import --quit`

Play: `godot --path . -- --dev-test-ads`

Default scene: `scenes/playtest/current_test.tscn`. All 50 existing C3 levels are selectable without fabricated completion scores. The independent `.current-energy-profile-v1/` uses real EnergyService: cap 30, new attempt costs 5, recovery 1 per 120 seconds, unfinished same-attempt restart free, win returns up to 5. Existing player/test saves are not read or migrated. `--dev-test-ads` explicitly enables development mock ads; it does not prove device SDK operation.

The optional `difficulty_test.tscn` remains an isolated free-energy diagnostic, not the default entry. No new theme, drinks, 10-color expansion, 46-level reduction or rejected reduced-angle experiment is included.

- [Current architecture and gameplay](docs/current/DEVELOPMENT.md)
- [Current changes](docs/current/PLAYTEST_UPDATE.json)
- [Related validation](docs/current/PLAYTEST_VALIDATION.json)
- [Remaining limits](docs/current/STATUS.md)
- [Reproduce focused checks](docs/current/TESTING.md)
- [File identity manifest](docs/current/SYNC_MANIFEST.json)
- [Third-party notices](distribution_notices/THIRD_PARTY_NOTICES.txt)

The prior 55dcb curated package omitted result/reward runtime dependencies and must not be deployed. This version restores them and directly tests the affected views. Native visual acceptance and phone/real-ad/signing checks remain unverified. This is a source sync and desktop test candidate, not a store release.
