# Reproduce focused checks

Run `python tools/run_current_checks.py --godot /path/to/Godot4.7.2`.

The runner verifies the source manifest, makes a fresh isolated copy, imports it, and runs result/reward dependency checks, home routing, the real-energy entry and live-energy settings checks. Outputs and test profiles stay in that copy. ERROR logs fail the run even when assertions pass. It never reads real player saves or launches a visible window.

`--output /path/to/new-output` selects a fresh output directory. `--real-clock` additionally waits for the existing actual-clock recovery test. `--full-regression` opts into retained baseline tests; it is not the default and was not run in this scope-reduced closeout. Current evidence is in PLAYTEST_VALIDATION.json; baseline evidence is separately in VALIDATION.json.

The victory/reward test mounts the actual orders_v3 host for ScreenLayout, checks all loaded texture instances and mipmaps, exact corrected PNG identity/dimensions, real numeric values and one-shot action dispatch. It does not synthesize native user input or certify pixel appearance. Native visuals, phone SDK/UMP and signed export remain separate gates.
