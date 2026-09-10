# City Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove conspicuous empty gaps from the playable city and make streets, courtyards, and the distant skyline read as one finished urban environment.

**Architecture:** Keep the existing deterministic procedural builder and MultiMesh batching. Measure route-side frontage from real generated transforms, add a non-colliding distant skyline layer outside the playable street network, tighten only the visual infill that leaves oversized lawns, and replace repetitive vacant-lot dressing with larger, varied courtyard compositions.

**Tech Stack:** Godot 4.6, GDScript, MultiMeshInstance3D, headless scene tests, OpenGL screenshot capture.

## Global Constraints

- Preserve all route geometry, stop clearances, and drivable-road collision guarantees.
- Keep generation deterministic and avoid external assets or new runtime dependencies.
- Retain MultiMesh batching for repeated city geometry.
- Do not modify the user's unrelated untracked `.uid` files.

---

### Task 1: City density regression

**Files:**
- Create: `tests/city_density_test.gd`
- Modify: `tests/run_checks.sh`

**Interfaces:**
- Consumes: `WorldBuilder.build(parent)`, the generated `FillerFront` and `FillerBack` MultiMeshes, and `RouteDefinition.waypoints()`.
- Produces: a scene-level regression test that measures route-side frontage coverage and verifies that a distant skyline exists.

- [ ] **Step 1: Write the failing test**

```gdscript
var front: MultiMeshInstance3D = game.world.get_node("FillerFront")
var back: MultiMeshInstance3D = game.world.get_node_or_null("FillerBack")
check(back != null and back.multimesh.instance_count >= 100, "city has a continuous distant skyline")
check(_frontage_coverage(front.multimesh, RouteDefinition.waypoints()) >= 0.82, "route streets have continuous frontage")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `XDG_DATA_HOME=/tmp/marsh-density godot4 --headless --path . --script res://tests/city_density_test.gd`

Expected: FAIL because `FillerBack` is absent and the current 56-metre lot grid leaves uncovered route-side samples.

- [ ] **Step 3: Register the test in the project check script**

```bash
for test in smoke_test full_route_test polish_test driving_test city_roads_test city_density_test traffic_test; do
```

- [ ] **Step 4: Re-run the isolated test after implementation**

Run: `XDG_DATA_HOME=/tmp/marsh-density godot4 --headless --path . --script res://tests/city_density_test.gd`

Expected: PASS with the measured coverage and skyline instance count printed.

### Task 2: Close skyline and block gaps

**Files:**
- Modify: `scripts/world/world_builder.gd`
- Test: `tests/city_density_test.gd`

**Interfaces:**
- Consumes: the existing reserved/occupied lot rectangles and `_multimesh_colored_boxes` batching helper.
- Produces: populated `FillerFront` and `FillerBack` MultiMeshes plus `city_buildings`/`city_backdrop_buildings` metadata.

- [ ] **Step 1: Tighten the interior lot cadence**

```gdscript
for x in range(-280, 921, 46):
    for z in range(-720, 421, 46):
        var size := Vector3(30, height, 14) if alternate else Vector3(14, height, 30)
        _place_city_block(parent, pos, size, reserved, occupied, front_entries, rng)
```

- [ ] **Step 2: Add a distant skyline outside the playable ring**

```gdscript
_build_backdrop_blocks(back_entries, rng)
parent.set_meta("city_backdrop_buildings", back_entries.size())
_multimesh_colored_boxes(parent, "FillerBack", body_mat, back_entries)
```

The backdrop uses larger low-detail blocks outside the outer road so it closes horizon holes without adding collision bodies inside playable space.

- [ ] **Step 3: Run the density test**

Run: `XDG_DATA_HOME=/tmp/marsh-density godot4 --headless --path . --script res://tests/city_density_test.gd`

Expected: PASS.

### Task 3: Make remaining open lots intentional

**Files:**
- Modify: `scripts/world/world_builder.gd`
- Modify: `tests/capture_city.gd`

**Interfaces:**
- Consumes: unoccupied rectangles, registered road surfaces, and the existing shared materials.
- Produces: larger courtyard surfaces with varied paths, trees, shrubs, seating, garage/parking accents, and additional route-level review captures.

- [ ] **Step 1: Replace tiny repeated garden strips with varied lot compositions**

```gdscript
var variant := (grid_x * 3 + grid_z) % 3
match variant:
    0: _append_courtyard_garden(...)
    1: _append_small_parking(...)
    2: _append_service_yard(...)
```

Every composition stays outside road margins, occupies a readable 16–20 m lot, and remains batched by material.

- [ ] **Step 2: Capture street and aerial review frames**

Run: `DISPLAY=:1 XDG_DATA_HOME=/tmp/marsh-city-capture godot4 --path . --rendering-method gl_compatibility --script res://tests/capture_city.gd`

Expected: `docs/review/dense_street.png`, `dense_quarters.png`, and route-side frames show no accidental grass voids or open horizon gaps.

- [ ] **Step 3: Run collision and full project checks**

Run: `GODOT_BIN=/home/debral/.local/bin/godot4 bash tests/run_checks.sh`

Expected: all available checks pass; if a pre-existing parser failure remains, report it separately and run every unaffected check directly.
