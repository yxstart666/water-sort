# User reference: pour spacing, tail and liquid feedback

Source: user_attachment_review/beca3d5cd211425ddf13f8d713c73d9f(1).mp4. ffprobe: 448×960, 30fps, 148.366667 seconds. Times below are original video times; contact sheets label relative time + start offset. Temporal precision is one frame (33 ms), not engine timing.

## Directly observed
- 17.733–17.800: middle bottle rises from its slot; approximately 20–25 native pixels of lift for a roughly 180px bottle. Its liquid cap is initially nearly level.
- 17.833–18.133: bottle holds raised; liquid cap alternately inclines left/right slightly. This is visible in lift_17_5_18_2_30fps.jpg. The fluid is not rigidly glued to its vessel.
- 18.433: stream begins extending downward. 18.467–18.533: advancing tip falls through receiving bottle. 18.567: first contact with liquid cap. 18.600: small local bulge; 18.633–18.767: rounded/crown-like impact lobes. The receiving bottle itself remains upright.
- 18.467 native full frame: receiving body width is about 59 px, receiving rim about 34 px. Pouring rim is above/right of receiving opening. Visible nearest rim-to-rim air gap is only about 4–8 native pixels (rough visual estimate; translucent antialiasing makes a precise boundary ambiguous), approximately 0.07–0.14 receiving-body widths. Stream connects the openings, not overlapping glass contours. This single frame is not proof of the minimum gap over the entire video.
- 18.800: long stream no longer visible. 18.800–18.967: receiving cap retains a central round mound with side lobes and a small tip. Source bottle begins returning while this feedback continues.
- 19.000: bulk mound has collapsed to a nearly flat elliptical cap with a narrow tip; two tiny detached green particles are clearly above it. 19.033–19.300: particles persist, then move down/fade. 19.333–19.367: cap appears settled. Rebound_18_8_19_4_30fps.jpg is the strongest tail evidence.
- 20.600–20.833: another source bottle rotates upright and returns while keeping liquid surface approximately gravity-level instead of matching bottle rotation. 20.867 onward: its visible liquid cap is almost flat. This return segment does NOT clearly establish a strong, repeated landing rebound; do not claim one was observed.

## Implementation recommendations, not measured competitor constants
Reuse the project's existing bottle transform, liquid-surface mesh/path and impact animation state; adjust them rather than introducing an unrelated replacement animation.
1. Solve pour target pose from transformed mouth/rim geometry, not bottle center anchors. Keep about 0.10 body-width visible clearance, with a conservative 0.08–0.14 range to tune; check actual silhouette clearance through approach, full tilt and return, mirrored both directions. An AABB overlap alone is not equivalent to glass intersecting.
2. Start stream after mouth clearance is established. Make stream head travel to current liquid height before impact activates (reference sample about 130ms from start to contact; scale to fall distance). Do not activate impact at pour start.
3. Separate stream visibility, surface impact envelope and detached particle lifetimes. On cutoff, retain local mound ~150–200ms, collapse into 1–3 small droplets, and finish residual feedback about 450–600ms after cutoff. Sample observed total cutoff-to-settle ~550ms. Source bottle return must not reset destination surface.
4. Keep impact localized near the stream hit point; reference mound is small relative to body width, not a giant hemispherical blob, foam bath or confetti. Suggested initial mound height 0.08–0.14 body width, detached drops 0.025–0.045 width, then tune against source.
5. For pickup, keep existing lift motion and add/retain modest damped liquid-cap inclination, roughly 0.04–0.07 body-width edge-height difference as a starting point. Landing should be subtler; strong repeated bounce is not supported by this inspected segment.
6. Preserve volume continuity and layer boundaries. Liquid cap updates continue after pour transaction and source return begin. Do not delete all transient liquid state at the transaction-complete callback.

## Files
- overview.jpg: 5-second sampling of original source, for navigation only.
- pour_17_23_overview.jpg: 5fps local event overview.
- pour_fullframe_18_467.png: native-resolution spacing reference.
- tail_18_4_19_2_30fps.jpg: consecutive 30fps stream/contact/cutoff frames.
- rebound_18_8_19_4_30fps.jpg: consecutive 30fps enlarged liquid cap/particles, nearest-neighbor enlargement.
- lift_17_5_18_2_30fps.jpg: consecutive 30fps pickup/slosh evidence.
- return_20_6_21_3_30fps.jpg: consecutive 30fps return evidence, limited landing response.
- reference_17_5_21_5.mp4: four-second user reference excerpt; time zero corresponds to original 17.5s. Cropping/contact-sheet generation is analysis only; no art assets or project code changed; nothing uploaded.
