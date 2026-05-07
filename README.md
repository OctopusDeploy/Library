Library
=======

A repository of step templates and other community-contributed extensions to Octopus Deploy.  The website to download step templates from is [https://library.octopus.com](https://library.octopus.com).

Organization
------------

* *Step templates* are in a temporary mixed migration state: legacy JSON remains under `/step-templates`, while migrated templates are authored under `/src/step-templates`
* The *library website* is largely under `/app`, with build artifacts at the root of the repository
* The `/tools` folder contains utilities to help with editing step templates

Contributing step templates or to the website
---------------------------------------------

Read our [contributing guidelines](https://github.com/OctopusDeploy/Library/blob/master/.github/CONTRIBUTING.md) for information about contributing step templates and to the website.

Reviewing PRs
-------------

### Reviewing script changes

Migrated templates keep script content beside `metadata.json` as normal source files such as `scriptbody.ps1`, `scriptbody.sh`, or `scriptbody.py`, so those changes can be reviewed directly in GitHub.

> [!NOTE]
> This repository is intentionally in a temporary mixed migration state. `step-templates/*.json` remains the compatibility output for the site and build pipeline, but new work should migrate templates into `src/step-templates/<template>/` instead of adding new legacy JSON-first templates.

Use `_diff.ps1` when you need to compare the generated JSON for a template against another branch or commit:

```powershell
# Compare ScriptBody against previous commit
.\tools\_diff.ps1 -SearchPattern "template-name"

# Compare against a specific commit or branch
.\tools\_diff.ps1 -SearchPattern "template-name" -CompareWith "master"
```

This outputs readable files to `diff-output/`:
- `template-name.ScriptBody.old.ps1`
- `template-name.ScriptBody.new.ps1`

> [!NOTE]
> Octopus Deploy still exports step templates as JSON. To migrate one or more templates incrementally, keep the exported JSON under `step-templates/`, then run `node tools/migrate-source-first.js --template <template-name> [--template <another-template-name> ...]` or `node tools/migrate-source-first.js --template-prefix <prefix>`. The script follows the same four-step flow used in the full migration tooling, but only for the selected templates. Migrated templates keep their `logo.png` beside `metadata.json` and `scriptbody.*`.

```powershell
node tools/migrate-source-first.js --template ssis-deploy-ispac-from-package-parameter.json
node tools/migrate-source-first.js --template ssis-deploy-ispac-from-package-parameter
node tools/migrate-source-first.js --template-prefix ssis-
```

If you need to discard an in-progress migration before committing, run:

```powershell
node tools/migrate-source-first-reset.js --template <template-name> [--template <another-template-name> ...]
node tools/migrate-source-first-reset.js --template-prefix <prefix>
```

### Checklist

When reviewing a PR, keep the following things in mind:
* `Id` should be a **GUID** that is not `00000000-0000-0000-0000-000000000000`
* `Version` should be incremented, otherwise the integration with Octopus won't update the step template correctly
* Parameter names should not start with `$`
* The `DefaultValue`s of `Parameter`s should be either a string or null.
* `LastModifiedBy` field must be present, and (_optionally_) updated with the correct author
* If a new `Category` has been created:
   * A `logo.png` file must be present beside the migrated template under `src/step-templates/<template>/`
   * The `switch` in the `humanize` function in [`gulpfile.babel.js`](https://github.com/OctopusDeploy/Library/blob/master/gulpfile.babel.js#L92) must have a `case` statement corresponding to it
