# Landmark Locking

Read this reference when the photo is visually complex, the target is small or partly occluded, or the landmark is a connected system rather than one simple building.

## Lock statement

Write this compact structure in working notes before generation:

```text
Target: <landmark name and scene position>
Scope: <core plus attached structures that define the landmark>
Identity anchors: <observable positive structural facts>
Exclude: <nearby buildings, roads, people, vehicles, vegetation, sky, water, light trails, text>
Uncertainty: <occluded or unverifiable parts, if any>
```

## Four-layer separation

1. **Core** — the structure whose identity is requested.
2. **Owned auxiliary structure** — a physically or semantically attached component required to recognize the same landmark.
3. **Occluder** — an object crossing the landmark in the photo but not belonging to it.
4. **Environment** — surrounding scene and atmosphere.

Generate layers 1 and 2 only. Removal of layers 3 and 4 must not remove a structurally necessary component from layer 2.

## Ambiguity decision gate

Before generation, enumerate plausible architecture or engineering targets when the request has not named one. If two or more remain, ask the user which one to transform. Visual dominance is not intent: the largest, nearest, brightest, or most centered structure may be a distractor.

For example, a road photo that contains two large cooling towers on the left and the distant Minpu Bridge pylons on the right is ambiguous without a named target. Ask whether to transform the cooling towers or Minpu Bridge. If the user says `闵浦大桥`, lock the smaller right-side bridge pylons, deck, and cable system and exclude the cooling towers completely.

## Composite landmarks

Define a minimum complete set. For example, the tested Nanpu Bridge scope is:

- one dominant circular approach viaduct;
- visible connecting ramps and repeated piers;
- the river-crossing main deck;
- two H-shaped cable-stayed pylons;
- fan-arranged stay cables;
- a readable structural connection between approach and main bridge.

Reject outputs that isolate only the loop, isolate only the cable-stayed span, add multiple loops, change the bridge type, or disconnect the system.

## Landmark-class anchor checklist

### Towers

- leg or shaft count and spread;
- major openings or arches;
- platform number and vertical order;
- taper and lattice or façade rhythm;
- crown, lantern, roof, antenna, or spire.

### Bridges and elevated roads

- structural bridge type;
- span and deck relationship;
- pylon, arch, or tower count and shape;
- stay cable, suspension cable, hanger, or pier pattern;
- approach, ramp, loop, and endpoint connections.

### Small or distant buildings

- silhouette and height-to-width ratio;
- roof or top outline;
- primary material/color blocks;
- only openings that are actually visible.

## Hard QA gates

All must pass:

1. The requested landmark—not a more visually dominant neighbor—was selected.
2. Major environment elements were not transferred into the miniature.
3. Every component declared in a composite scope remains present and connected.

Do not let high style quality compensate for a failed gate.

