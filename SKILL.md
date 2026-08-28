---
name: landmark-miniature-model
description: Isolate a named landmark or distinctive building from a complex source photo, preserve its structural identity, and render it as a collectible miniature architectural model with an optional comparison poster. Use for 地标转绘、建筑微缩模型、复杂画面主体锁定, including composite bridges; not for generic city dioramas or arbitrary photo stylization.
---

# Landmark Miniature Model

Turn the requested landmark—not the whole scene—into a clean collectible architectural miniature. Treat the source photo as authoritative for identity and any supplied examples as style-only references.

## Inputs

Identify:

- The source photo and requested landmark.
- Any local style-reference folder or images.
- Whether the user wants the isolated model, a comparison poster, or both.
- The output location. Never overwrite source photos.

If several landmarks are plausible and the request does not identify one, ask for the target. Otherwise proceed from visual evidence.

## Workflow

1. Inspect the source photo and enough style references to distinguish stable style traits from the geometry of individual example buildings. Do not claim model fine-tuning or permanent visual learning.
2. Before generation, create a concise target-lock statement containing the landmark name, scene position, exact scope, identity anchors, attached structures that belong to it, explicit exclusions, and any uncertainty.
3. Separate the image into four layers: landmark core, landmark-owned auxiliary structures, occluders, and environment. Transfer only the first two layers.
4. For a complex or composite landmark, read [references/landmark-locking.md](references/landmark-locking.md). Define the minimum complete landmark before generating.
5. Read [references/style-profile.md](references/style-profile.md) for the learned visual language. When the user supplies a new style folder, inspect it and update only the traits supported consistently by those references.
6. Use the available image generation/edit tool with the source photo as the geometry authority and selected local references as style-only guidance. Build the request with [references/prompt-and-qa.md](references/prompt-and-qa.md).
7. Apply the hard QA gates before scoring style: correct target, environment excluded, and declared composite scope complete. Reject an output that fails any gate even when it looks attractive.
8. Make a targeted revision for a specific failure. Stop after two unsuccessful revisions for the same input and report the unresolved limitation rather than drifting away from source geometry.

## Identity Rules

- Preserve observable structure before surface decoration: silhouette, massing, openings, support count, platform count, roof or crown, bridge type, tower count, cable or hanger system, and connections.
- Reconstruct a lightly occluded continuation only when the visible geometry supports it. Do not borrow nearby buildings, roads, or generic landmark memories to invent key structures.
- When the target is small, retain only verifiable outline, massing, roof, and major color blocks. Do not fabricate doors, windows, stairs, plaques, or ornaments.
- Standardizing to a product-style three-quarter view must not expose invented hidden-side geometry. Prefer the source-supported orientation when identity would otherwise become speculative.

## Model Presentation

- Produce one isolated collectible architectural or engineering miniature.
- Use a warm ivory seamless background, generous negative space, soft diffuse product lighting, and a restrained contact shadow.
- Keep the full miniature visible and centered. Avoid people, vehicles, vegetation, skyline, water, terrain dioramas, labels, plaques, logos, and watermarks unless the user explicitly requests them.
- Favor refined physical materials and credible small-scale construction. Avoid glossy plastic, toy-block proportions, fantasy ornament, and geometry copied from a style reference.

## Comparison Poster

When requested, first generate the isolated model, then compose the poster deterministically with [scripts/compose-comparison.ps1](scripts/compose-comparison.ps1):

- Canvas: `1200×1600`; top and bottom panels: `1200×800` each.
- Top: the original photo, aspect-filled to `3:2` with no stretching or side bars. Use the landmark as crop focus.
- Bottom: the model's visible bounds, including contact shadow, centered inside `x=20%–80%`, `y=20%–80%` of the bottom panel.
- Preserve aspect ratio. A tall subject is limited by safe-area height; a wide subject by safe-area width.
- If a portrait crop cannot preserve the complete landmark, prioritize its identity-bearing region and explicitly report the cropped structure.

Inspect the generated model and estimate two source-pixel rectangles: `ModelBounds` for the visible model plus contact shadow, and a slightly larger `ModelCrop` containing clean background around it. Pass them as `x,y,width,height`; the script removes the sampled seamless background and prints the crop, final bounding box, margins, and center offset as JSON.

```powershell
./scripts/compose-comparison.ps1 `
  -PhotoPath <photo> -ModelPath <model> -OutputPath <poster> `
  -ModelBounds 'x,y,width,height' -ModelCrop 'x,y,width,height' `
  -PhotoFocusX 0.5 -PhotoFocusY 0.5 -FitBy auto
```

Inspect the poster visually after running it. Adjust the crop focus or measured bounds only when the image shows a concrete layout error.

## Deliverables

Use clear revisioned filenames such as:

- `01-地标名-模型-r1.png`
- `01-地标名-对照海报-r1.png`
- `调试报告.md` when testing or revising the workflow

Report the lock decision, QA result, known uncertainty, final file paths, and whether the Skill itself was changed. Keep sources read-only.

