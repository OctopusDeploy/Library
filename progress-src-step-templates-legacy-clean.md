# Progress Handoff: `src-step-templates-legacy-clean`

## Purpose

This branch is migrating legacy step template authoring away from packed files in `step-templates/*.json` and into source folders under `src/step-templates/<template-name>/`.

The target shape for a migrated template is:

- `src/step-templates/<template-name>/metadata.json`
- optional `scriptbody.ps1`
- optional `scriptbody.sh`
- optional `scriptbody.py`
- optional `predeploy.ps1`
- optional `deploy.ps1`
- optional `postdeploy.ps1`

## What Was Done

The branch added infrastructure and migrated an initial set of script-bearing templates in batches.

Key commits on that branch at the time of this handoff:

- `dc7e4979` Add legacy-backed step-template source infrastructure
- `d6d73b62` Add step-template migration verification helpers
- `e1dcec3b` Move proof set metadata into source root
- `d1c13e56` Extract proof set source files into source root
- `72ac72b3` Move script-bearing batch 1 metadata into source root
- `19c21070` Extract script-bearing batch 1 source files into source root
- `c0f16dd0` Move script-bearing batch 2 metadata into source root
- `12347221` Extract script-bearing batch 2 source files into source root
- `e71d0c46` Ignore temporary `.tmp*` folders

## Reconstructed Workflow Used On That Branch

The branch introduced and used these scripts:

- `tools/Prepare-StepTemplateSourceOriginals.ps1`
- `tools/Pack-SourceStepTemplates.ps1`
- `tools/Finalize-StepTemplateSourceMigration.ps1`

Operational flow:

1. Prepare a template by exporting legacy script bodies out of `step-templates/<name>.json`.
2. Move the template metadata into `src/step-templates/<name>/metadata.json`.
3. Store script content as real files in the template folder.
4. Pack from source back into legacy layout and verify the output still round-trips.
5. Finalize by removing embedded script properties from `metadata.json` after the extracted files are confirmed.

## State At Time Of Handoff

Counts observed while inspecting the branch:

- `step-templates/*.json`: `584`
- `src/step-templates/<template>/metadata.json`: `212`
- remaining legacy-only templates: `372`

Additional observations:

- `212` migrated template folders already had extracted script files.
- Exactly one migrated template still appeared partially finalized:
  - `src/step-templates/azure-function-deployment/metadata.json`
  - still contained:
    - `Octopus.Action.CustomScripts.PreDeploy.ps1`
    - `Octopus.Action.CustomScripts.Deploy.ps1`

## Recommended Next Actions On That Branch

1. Finalize `azure-function-deployment` so its metadata no longer carries embedded custom script properties.
2. Choose the next migration batch from the `372` legacy-only templates.
3. Repeat the same metadata move, extraction, pack verification, and finalize sequence.
4. Continue until `src/step-templates` becomes the complete source of truth for all templates.

## Notes For Continuing On Another Machine

If resuming this work elsewhere:

- check out `src-step-templates-legacy-clean`
- read this file first
- inspect the three migration scripts above
- verify the current counts before starting the next batch
- use small batches and validate each one before moving on
