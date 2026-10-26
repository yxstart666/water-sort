# ColorPause — cloth layer handoff (NON-PRODUCTION)

Prepared in cloud workspace only. No production changes, user-PC writes, Codex messages, publication, or image-pixel edits. All four PNGs are byte-for-byte copies; see SOURCE_MANIFEST.json. This is a reviewable art handoff, NOT an integrated or QA-passed game build.

## Scope and invariants

- Keep the actual existing game bottle, liquid, material, dimensions, animation, hitbox, and skin system. **Never replace it with the generated covered-bottle silhouette.** `reference_only/original_glass_front_material.png` identifies the original glass source; production should keep its existing asset binding, not add a competing bottle.
- `layers/cloth_overlay_source.png` is the accepted-style cloth-only source, with no baked task badge. Layer it over the existing bottle only while locked. No other font, material, or skin redesign is authorized by this pack.
- `layers/order_frame_existing.png` is the native empty order card: WHITE RIM, NAVY INTERIOR, no baked icon or text. Reuse it as a separate runtime badge background.
- `reference_only/accepted_cloth_badge_reference.png` shows the accepted illustration direction, but contains a baked blue task badge and Chinese text. REFERENCE ONLY: do not ship it as a runtime condition or use its generated silhouette as the actual bottle.

## Alpha measurements — unmodified source

RGBA cloth canvas: 1024 × 1536. Bboxes use exclusive right/bottom edges.

| Alpha threshold | Bounding box (left, top, right, bottom) | Size |
|---|---|---|
| > 0 | (0, 63, 1010, 1472) | 1010 × 1409 |
| > 1 | (164, 66, 862, 1437) | 698 × 1371 |
| > 16 | (166, 68, 859, 1435) | 693 × 1367 |
| > 128 | (167, 68, 858, 1434) | 691 × 1366 |
| > 250 | (168, 70, 857, 1433) | 689 × 1363 |

866,749 pixels are alpha 0; 6,749 are alpha 1/255; 5,499 are alpha 2–16/255. The apparent gray halo in the viewer is NOT evidence of an opaque rectangular background. However the source is also NOT perfectly clean alpha-zero outside the physical cloth: faint alpha-1 support extends 167 px left and 152 px right beyond the >128 bbox. Core-to->1 bbox expansion is only 3 px left / 4 px right, 2 px top / 3 px bottom. Thus use the strong-alpha bbox for layout, not the farthest nonzero speckle. Native alpha blending, filtering, premultiplication, and mipmaps still require dark/light-background QA; no cleanup was performed here.

## Proposed registration — requires native QA

Original bottle source: 165 × 410; nonzero bbox (17, 9, 149, 399), visible width W=132 and height H=390. Its center is (83,204). Keep this bottle's native scene transform and child hierarchy. The values below are starting art-placement proposals, NOT verified final integration values.

Define normalized bottle-visible coordinates u=(x−17)/132, v=(y−9)/390. The intended cloth covers approximately the upper 80% of the bottle, leaving the original bottom visible. Align the cloth strong-alpha bbox (167,68,858,1434) to u=0..1, v=0..0.80. In original-bottle local pixels this means scale X=132/691≈0.1910275, scale Y=312/1366≈0.2284041; canvas top-left x≈−14.9016, y≈−6.5315. The strong cloth bbox then spans (17,9) to (149,321), leaving the original bottle visible below y=321. Equivalent cloth source-bbox coordinates normalized to its canvas are (0.163086, 0.044271) to (0.837891, 0.933594). Treat this as registration metadata only; images remain unmodified.

**Fit note:** cloth physical aspect ≈0.506 versus the intended 132 × 312 upper-bottle target ≈0.423. Uniform fit to the intended cloth height would be about 19.6% wider than the bottle, not 49.5% (that latter number would incorrectly assume full-height cloth). The proposed upper-80% registration uses modest nonuniform runtime scaling; the final native target may be approximately 132–140 px wide × 300–320 px high, centered on the original bottle. It must leave the original lower glass visible. Native QA must compare knit appearance, shoulder/neck coverage, and alignment; a bounding-box fit alone cannot prove these. Do not silently widen/change the original bottle, flatten into a new bottle asset, or claim a ready-to-ship fit. If runtime fit is unacceptable, return for an explicitly approved art correction rather than editing pixels in this handoff.

Layer order: existing bottle/liquid < locked cloth overlay < empty native order frame < runtime task icon/count/label. On unlock remove/fade the cloth and badge according to existing gameplay; reveal the same original bottle beneath. Preserve actual game geometry and interactions.

## Runtime task badge — data-driven, not blue ×1

Task content must come from the current existing sealed-order-bottle objective: its actual order-bottle color/visual, required or remaining count using the game's existing semantics, and localized condition label. Reuse the existing sealed-order-bottle icon assets; do not invent a replacement generic bottle or hard-code a blue bottle, ×1, or Chinese-only text. Make it clear the icon means an ORDER condition, not merely the liquid in the covered bottle. Validate more than one target color and counts greater than one.

Starting layout, in normalized visible-bottle coordinates:

- **Board / small mode:** frame center (u=0.50,v=0.32), width at most 0.60W (=79.20 source-local px), preserving original 157:204 canvas ratio, so height ≈102.91 px (=0.2639H). Bounds approximately u=0.20..0.80, v=0.1881..0.4519: the panel stays within 60% of bottle width. Frame content safe zone is its central 72% width and 66% height. Use a large order-bottle icon with count beside/below it; no tiny explanatory sentence. Put the localized condition hint in the existing separate selected-task/help area, associated clearly with the covered bottle. If the count cannot remain legible at actual device scale, use the existing compact badge treatment or escalate layout; never overflow into adjacent bottles.
- **Full intro / enlarged illustration:** frame center (0.50,0.39), width 0.84W (=110.88 source-local px), preserving frame ratio; height ≈144.07 px (=0.3694H), bounds u=0.08..0.92, v≈0.2053..0.5747. In the same safe zone use the current order icon + count, with the localized task word below. The surrounding explanation must state what completing the order unlocks. No baked single-color task text.

These badge positions are starting candidates, not measured runtime results. Check pointer anchors, scaling, localization, z-order, overlap, and minimum-device legibility in the native scene. Existing font and native UI style remain unchanged.

## Required before production acceptance

1. Confirm the actual bottle binding remains the original asset before, during, and after unlock.
2. Validate cloth registration, shoulder/neck coverage, nonuniform knit appearance, neighboring-bottle clearance, and alpha halo on dark/light gameplay backgrounds at native display scale.
3. Bind badge icon/color/count/localized label to real objective data; test multiple colors, count >1, completion, and localization fallback.
4. Check small-board mode versus full-intro mode separately: panel stays inside bottle width; small badge remains legible; separate hint explains the condition.
5. Verify lock/unlock transition and input rules through the existing gameplay implementation. This pack contains no gameplay code and cannot establish behavior.
6. Capture native screenshots/results for parent review. Do not publish or replace production assets until authorized.
