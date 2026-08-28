# Prompt Construction and QA

## Generation request template

Adapt this structure to the actual photo instead of copying placeholders literally:

```text
Use case: style-transfer with landmark isolation.
Authoritative source: <source image>.
Target lock: only <landmark and scene position>.
Target scope: <complete core and owned auxiliary structures>.
Identity invariants: <observable structural anchors>.
Style references: <selected local references> are style-only; do not borrow their building geometry.
Presentation: one collectible architectural miniature, warm ivory seamless background, soft diffuse product lighting, subtle contact shadow, centered, complete, no text.
Remove completely: <occluders and environment>.
Avoid: <most likely identity confusions, wrong structure types, copied surroundings, toy styling, text, watermark>.
```

Use explicit negative confusions that are plausible for the target. For a cable-stayed bridge, name arch bridge and suspension bridge when those are realistic model errors. For a tower, name wrong leg count, filled openings, missing platforms, or altered crown as appropriate.

## QA order

### 1. Hard gates

- Correct target selected.
- Environment excluded.
- Composite scope complete and connected.

### 2. Scored review

| Criterion | Points |
|---|---:|
| Landmark identity fidelity | 30 |
| Learned style match | 30 |
| Miniature scale feeling | 15 |
| Material and color | 10 |
| Composition and background | 10 |
| Artifact control | 5 |

Recommended pass threshold: total `>=85` and identity `>=24/30`, with every hard gate passed.

## Revision strategy

Revise only the failed criterion. Preserve already-correct geometry, material, background, and composition explicitly. Typical corrections:

- restore a missing pylon, platform, loop, arch, or connector;
- remove an invented door, window, stair, scenic base, or neighboring building;
- correct a bridge family or tower silhouette;
- reduce glossy plastic appearance without changing geometry.

After two unsuccessful targeted revisions for the same source, stop and report which identity evidence is too weak or which image-generation behavior remains unstable.

