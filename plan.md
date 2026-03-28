# Numbered Migration Plan For Source-First Step Templates

## Summary

This plan moves authored step templates and related authoring assets out of `step-templates/` and into `src/`, keeps `step-templates/*.json` as generated compatibility output, and updates `npm run dev` plus watch mode to regenerate packed JSON from source.

The work lands as one PR, but execution is organized into a proof batch followed by migration batches of 100 templates each. Validation is strict: each migrated template must repack to a byte-identical match against its saved `.json.orig`.

The existing pack and unpack scripts must not be altered. They remain the canonical mechanism for producing identical packed output. Any additional behavior needed for migration or the new source-first workflow should be implemented in separate helper scripts. Scripts that are temporary migration scaffolding should be clearly named with a `migration-` prefix.

A key requirement during migration is that the dev workflow remains usable at every intermediate point. After the proof batch, after batch 100, and after any later batch, `npm run dev`, tests, and watch mode must continue to work by combining authored templates already moved into `src/` with any templates not yet migrated.

## Numbered Steps

1. Write this plan into `plan.md`.

2. Define and document the new source contract under `src/`:
   - `src/step-templates/<template>/metadata.json`
   - `src/step-templates/<template>/scriptbody.<ext>`
   - optional `predeploy.ps1`, `deploy.ps1`, `postdeploy.ps1`
   - placeholder values in `metadata.json` for script-backed properties
   - move shared authoring assets from `step-templates/logos` to `src/step-templates/logos`
   - move template tests from `step-templates/tests` to `src/step-templates/tests`

3. Preserve the existing packing and unpacking behavior unchanged:
   - do not modify `tools/_pack.ps1`
   - do not modify `tools/_unpack.ps1`
   - do not modify the existing `StepTemplatePacker` import/export logic
   - treat those scripts as the source of truth for byte-identical repacking and diff validation

4. Inventory existing helper scripts and classify them:
   - keep scripts still needed after migration
   - mark temporary migration-only scripts with `migration-` prefixes
   - identify scripts that become obsolete once source files are first-class
   - explicitly evaluate `_diff.ps1` and any related review/extraction helpers for removal
   - plan README/docs updates around the retained and removed scripts

5. Update `.gitignore` so `step-templates/` is treated as generated output only when the migration is complete:
   - prepare ignore rules for generated `step-templates/*.json`
   - ignore temporary `step-templates/*.json.orig`
   - ensure no newly generated files under `step-templates/` are accidentally checked in once cutover is complete
   - keep migration-safe behavior while legacy tracked JSON still exists during intermediate batches inside the PR

6. Create helper scripts for the new workflow without changing the old ones:
   - create permanent source-to-generated helper scripts for dev and watch flows
   - create temporary `migration-*` scripts for prepare, verify, batch migration, and cleanup work
   - keep permanent and migration-only responsibilities clearly separated

7. Implement permanent helper tooling that supports mixed migration state while still using the existing packer:
   - treat `src/step-templates/*` as authoritative for migrated templates
   - treat legacy `step-templates/*.json` as the source for templates not yet migrated
   - generate or refresh packed `step-templates/*.json` only for templates that already exist in `src/`
   - leave untouched legacy packed JSON in place for templates not yet migrated
   - stage source template material into the temporary legacy layout expected by the unchanged packer
   - stage logos and test assets into the generated layout as needed for existing validation/build logic
   - support generating all migrated templates for dev startup
   - support generating a single migrated template for watch mode

8. Implement migration-only prepare tooling in `migration-*` scripts for a single template:
   - copy `step-templates/<template>.json` to `step-templates/<template>.json.orig`
   - `git mv` `step-templates/<template>.json` to `src/step-templates/<template>/metadata.json`
   - use the existing unpack behavior to extract scripts without changing its implementation
   - move or normalize unpacked outputs into the final source folder layout
   - replace embedded script values in `metadata.json` with placeholders

9. Implement migration-only validation tooling in `migration-*` scripts for a single template:
   - reconstruct the temporary legacy layout needed by the unchanged packer
   - invoke the existing pack behavior to regenerate `step-templates/<template>.json`
   - diff regenerated `step-templates/<template>.json` against `step-templates/<template>.json.orig`
   - fail unless they are identical apart from the accepted normalization differences:
     - `"$Meta.ExportedAt"` may be reformatted by the unchanged packer
     - a single trailing newline at end of file may be added or removed
   - remove `.json.orig` only after validation succeeds

10. Update dev/build behavior so `npm run dev` works throughout migration:
   - on startup, regenerate packed JSON for all templates currently authored under `src/step-templates/*`
   - keep unmigrated legacy JSON files available in `step-templates/`
   - then run the existing build pipeline against the complete effective packed set
   - ensure this works after the proof batch, after batch 100, and at every later partial-migration checkpoint

11. Update watch behavior so hot reloading works throughout migration:
   - changes under `src/step-templates/**/*` regenerate only the corresponding migrated packed template, then rerun downstream aggregate/site generation
   - changes to unmigrated legacy `step-templates/*.json` continue to work until those templates are migrated
   - shared asset changes such as logos or test helpers trigger the smallest safe regeneration scope
   - the site reload behavior should remain functional regardless of how many templates have already moved to `src/`

12. Update validation/tests to align with the migration-safe source-first model:
   - validations continue to run against the effective packed `step-templates/*.json` set
   - any test paths that currently point at `step-templates/tests` are updated to use `src/step-templates/tests` as the authored location
   - generated validation inputs are reconstructed as needed for unchanged pack/unpack compatibility
   - test and dev commands must pass in mixed-state migration checkpoints, not only after final cutover

13. Scan the repo and select the initial proof batch to cover migration edge cases:
   - template with no `ScriptBody`
   - template with non-PowerShell `ScriptBody`
   - template with `ScriptBody` plus custom staged scripts
   - template with only staged scripts if one exists
   - template with unusual or metadata-heavy structure if one exists

14. Migrate the proof batch using the full prepare, pack, diff, and cleanup workflow until every proof template passes strict `.json.orig` validation.

15. Verify the migration-safe developer workflow immediately after the proof batch:
   - run dev startup with only the proof templates in `src/`
   - confirm generated packed JSON is created for proof templates
   - confirm unmigrated legacy templates still participate in the site build
   - confirm tests still pass
   - confirm watch mode and hot reload still work

16. Review the proof batch results and lock any required naming, placeholder, helper-script, or workflow adjustments before bulk migration begins.

17. Migrate the remaining templates in batches of 100:
   - for each batch, prepare every template with `.json.orig`
   - `git mv` into `src/step-templates/<template>/metadata.json`
   - unpack script files and replace metadata script values with placeholders
   - regenerate packed JSON through helper scripts that rely on the unchanged packer
   - diff each regenerated packed file against its `.json.orig`
   - verify dev startup, tests, and hot reload still work with the repo in its new mixed-state checkpoint
   - do not proceed to the next batch until the full current batch validates cleanly

18. Migrate shared non-template authoring assets:
   - move `step-templates/logos` to `src/step-templates/logos`
   - move `step-templates/tests` to `src/step-templates/tests`
   - update any build, validation, or helper script references to the new authored locations
   - ensure generated layout still provides whatever the unchanged validation/build path expects

19. Update README and contributor docs to reflect both the migration period and the final workflow:
   - explain that migrated templates live in `src/step-templates/*`
   - explain that unmigrated templates may temporarily still exist in legacy form during the migration
   - explain that `npm run dev` and watch mode support both states during the transition
   - explain that `step-templates/*.json` becomes generated output after full cutover
   - document the permanent helper scripts used for generation and watch mode
   - document temporary `migration-*` scripts and note they are disposable after migration
   - remove review guidance that depends on unpacking JSON blobs for diffs once full cutover is complete

20. Remove or retire obsolete tooling and documentation after the migration is proven:
   - remove `_diff.ps1` if it is no longer needed
   - evaluate other pack/unpack-adjacent utilities and remove any that only existed to work around unreadable JSON diffs
   - keep unchanged pack/unpack scripts and any permanent source-to-generated helpers still required post-migration
   - update docs so only supported scripts remain documented

21. Perform final cutover after the last migration batch:
   - confirm all templates now exist under `src/step-templates/*`
   - switch `.gitignore` and workflow assumptions fully to generated-only `step-templates/*.json`
   - ensure no legacy authored template JSON remains outside generated output

22. After all batches and asset moves are complete, run full generation and repo-wide validation to confirm every packed JSON file is reproducible from `src/step-templates/*`.

23. Finalize the PR state:
   - ensure `src/step-templates/*` is the only authored source
   - ensure packed `step-templates/*.json` are generated and untracked
   - ensure `.json.orig` files are removed
   - ensure docs and dev workflow reflect the new model
   - retain only the helper scripts needed after migration
   - remove temporary `migration-*` scripts and obsolete review helpers that are no longer needed

## Script Roles

- Permanent scripts:
  - source-to-generated helper scripts needed for `npm run dev`, watch mode, and ongoing local authoring
  - unchanged legacy pack/unpack scripts still used for byte-identical generation
- Migration-only scripts:
  - must be clearly named with `migration-` prefixes
  - include prepare, verify, batch migration, and cleanup helpers
  - may be deleted after the migration is complete
- Obsolete scripts to evaluate for removal:
  - `_diff.ps1` is expected to become unnecessary because GitHub diffs become readable from real source files
  - any other script whose purpose was to compensate for embedded JSON script blobs should be reviewed for removal

## Public Interfaces And Behavior

- New authored source layout:
  - `src/step-templates/<template>/metadata.json`
  - `src/step-templates/<template>/scriptbody.<ext>`
  - optional staged script files
  - `src/step-templates/logos`
  - `src/step-templates/tests`
- Existing runtime/site interface remains unchanged:
  - the site still consumes packed JSON from `step-templates/*.json`
- Contributor workflow changes:
  - contributors edit migrated templates in `src/step-templates/*`
  - contributors may still encounter unmigrated legacy JSON during the migration window inside the PR
  - contributors no longer need special diff tooling for migrated templates
  - contributors rely on generation and validation tooling for round-trip safety
- Existing pack/unpack commands remain behaviorally unchanged:
  - helper scripts wrap them rather than replacing or editing them

## Test Plan

- Verify generation from migrated templates in `src/step-templates/*` produces valid packed `step-templates/*.json`
- Verify the proof batch covers the intended edge cases and every template matches its `.json.orig` exactly after repack
- Verify each 100-template migration batch passes strict `.json.orig` validation before the next batch starts
- Verify `npm run dev` works after the proof batch, after batch 100, and after every later batch checkpoint
- Verify hot reload works for migrated templates in `src/step-templates/*` throughout the migration
- Verify unmigrated legacy templates continue to participate in dev/test/build until they are migrated
- Verify `.gitignore` prevents newly generated files in `step-templates/` from being staged unintentionally at final cutover
- Verify shared asset changes in `src/step-templates/logos` and `src/step-templates/tests` trigger the correct downstream regeneration
- Verify existing validations still pass against the effective packed outputs
- Verify existing pack/unpack behavior is unchanged and still produces identical files for diffing
- Verify `_diff.ps1` and any other obsolete review helpers can be removed without losing required workflow support
- Verify `.orig` artifacts are temporary, untracked, and removed after successful validation
- Verify temporary `migration-*` scripts can be removed without affecting the post-migration dev workflow

## Assumptions And Defaults

- This remains one cutover PR composed of smaller commits
- The proof batch comes first, and subsequent migration batches are fixed at 100 templates each
- During migration, the repo must support a mixed state where some templates are authored in `src/step-templates/*` and others remain as legacy JSON
- `metadata.json` uses placeholders for script-backed properties
- Packed JSON equivalence is strict apart from two accepted normalization differences:
  - `"$Meta.ExportedAt"` may be rewritten into the unchanged packer's normalized format
  - a single trailing newline at end of file may differ
- `step-templates/` becomes generated-only after final cutover, not before the last migrated batch is complete
- Shared authoring assets currently under `step-templates/logos` and `step-templates/tests` move to `src/step-templates/`
- `.json.orig` files are local migration artifacts only and are never committed
- Existing pack/unpack scripts remain unchanged; all new behavior is introduced through helper scripts around them
