# Plan: Rebuild The Step Template Unpack Work From `master`

## Goal

Start from `master` and implement a safe migration path from legacy packed templates in `step-templates/*.json` to editable source folders in `src/step-templates/<template-name>/`.

The result should preserve existing site behavior while making script changes reviewable as normal files.

## Desired End State

For every step template:

- source lives under `src/step-templates/<template-name>/`
- `metadata.json` contains template metadata only
- script content lives in separate files
- packed `step-templates/*.json` can still be generated for existing consumers
- migration can be done gradually in batches without breaking the build

## Constraints

- `master` currently treats `step-templates/*.json` as the legacy artifact shape
- the migration must be incremental, not a flag day rewrite
- reviewability matters, especially for script changes
- round-trip equivalence matters more than elegance

## Work Breakdown

### 1. Define The Source Format

Choose and document the source-root contract:

- `src/step-templates/<template>/metadata.json`
- `scriptbody.ps1|sh|py` when the main script exists
- `predeploy.ps1`, `deploy.ps1`, `postdeploy.ps1` for custom script stages
- `logos/` and `tests/` remain special-case directories under `src/step-templates`

Update `README.md` so contributors and reviewers know the new source layout.

### 2. Add Packing Support

Create a script that reads source folders and regenerates legacy packed outputs under `step-templates/`.

Requirements:

- copy `metadata.json` into a temporary legacy shape
- copy extracted script files into temporary `*.ScriptBody.*`, `*.PreDeploy.ps1`, `*.Deploy.ps1`, `*.PostDeploy.ps1`
- call the existing legacy packing logic
- write final packed JSON back into `step-templates/`
- avoid mutating source files during packing

This is the bridge that allows gradual migration without breaking existing consumers.

### 3. Add Preparation Support

Create a script that takes existing packed templates and prepares source folders from them.

Requirements:

- read `step-templates/<name>.json`
- export embedded legacy scripts to temporary real files
- move those extracted scripts into `src/step-templates/<name>/` using normalized names
- preserve the original text content exactly before final cleanup

This script should support running on a selected list of template names so migration can happen in batches.

### 4. Add Finalization Support

Create a script that finalizes a migrated template after verification.

Requirements:

- confirm extracted script files match the prepared originals
- remove embedded script properties from `metadata.json`
- rename any `*-orig.*` file to its final normalized name
- leave metadata-only templates untouched

Finalization should happen only after round-trip verification passes.

### 5. Add Verification Helpers

Add lightweight helpers or tests that prove source-to-packed round trips are safe.

Verification should cover:

- packed JSON can be regenerated from source
- script content matches legacy content after normalization
- no unexpected packed script sidecar files remain in `step-templates/`
- representative templates across PowerShell, Bash, Python, and custom script stages

### 6. Prove The Flow On A Small Proof Set

Before migrating many templates, choose a small and varied proof set:

- one PowerShell `ScriptBody` template
- one Bash `ScriptBody` template
- one Python `ScriptBody` template
- one template using custom script stages if available

For the proof set:

1. prepare from legacy
2. move metadata into source root
3. extract scripts
4. repack
5. compare results
6. finalize

Do not scale out until this set works cleanly.

### 7. Migrate Script-Bearing Templates In Batches

After the proof set passes, migrate the script-bearing templates in manageable batches.

Per batch:

1. choose a bounded list of template names
2. prepare originals from legacy packed files
3. add `src/step-templates/<name>/metadata.json`
4. add extracted script files
5. repack and compare
6. finalize
7. commit the batch

Keep commits small enough that regressions are easy to isolate.

### 8. Handle Edge Cases Explicitly

Expect special handling for:

- templates with custom pre/deploy/post-deploy scripts
- templates with empty custom script properties
- templates that are metadata-only
- templates whose names or casing are inconsistent
- templates that already have partial source-root structure

Capture these cases in docs or helper script behavior rather than solving them ad hoc each time.

### 9. Finish The Remainder

Once script-bearing templates are stable, migrate the rest of the templates so all authoring lives under `src/step-templates`.

The packing step can continue to generate legacy JSON until the repo no longer needs it.

### 10. Final Cleanup

After the full migration is complete:

- confirm every template exists in source-root form
- confirm packed JSON is generated, not hand-authored
- remove obsolete migration-only helpers if they are no longer needed
- keep only the pack path that is still required operationally

## Recommended Order Of Execution

1. document the new source contract
2. implement pack-from-source support
3. implement prepare-from-legacy support
4. implement finalize support
5. add verification helpers
6. migrate a proof set
7. migrate script-bearing templates in batches
8. migrate remaining templates
9. clean up once source-root becomes authoritative

## Definition Of Done

The migration is complete when:

- every template has a source folder in `src/step-templates`
- script content is stored as real files, not JSON string blobs
- pack tooling reproduces the legacy output reliably
- reviewers can inspect script changes as normal file diffs
- the repository no longer depends on manual editing of `step-templates/*.json`
