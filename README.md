Library
=======

A repository of step templates and other community-contributed extensions to Octopus Deploy.  The website to download step templates from is [https://library.octopus.com](https://library.octopus.com).

Organization
------------

* *Step templates* are authored under `/src/step-templates`, with generated compatibility JSON under `/step-templates`
* The *library website* is largely under `/app`, with build artifacts at the root of the repository
* The `/tools` folder contains utilities to help with editing step templates

Contributing step templates or to the website
---------------------------------------------

Read our [contributing guidelines](https://github.com/OctopusDeploy/Library/blob/master/.github/CONTRIBUTING.md) for information about contributing step templates and to the website.

Reviewing PRs
-------------

### Reviewing script changes

Step template scripts now live beside `metadata.json` as normal source files, so diffs are readable in GitHub and in local tools:

- `scriptbody.ps1`
- `scriptbody.sh`
- `scriptbody.py`

> [!NOTE]
> This repository previously stored script content only inside `step-templates/*.json` as escaped strings. The source-first layout keeps editable script content under `src/step-templates/<template>/`, while the legacy JSON remains a generated compatibility output.

If you need to compare the generated JSON with an older branch or commit, you can still use the `_diff.ps1` tool:

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
> Octopus Deploy still exports step templates as JSON. If you start from an export, save the file under `step-templates/`, run `powershell .\tools\_unpack.ps1 -SearchPattern "template-name"`, then move the resulting `metadata.json` and `scriptbody.*` files into `src/step-templates/<template>/`. Build tooling must continue to generate `step-templates/*.json`; that generated output is the compatibility contract this repository is preserving. The exact retrieval flow used by `library.octopus.com` is not documented here, but generated JSON in the legacy location is believed to remain compatible.

### Checklist

When reviewing a PR, keep the following things in mind:
* `Id` should be a **GUID** that is not `00000000-0000-0000-0000-000000000000`
* `Version` should be incremented, otherwise the integration with Octopus won't update the step template correctly
* Parameter names should not start with `$`
* The `DefaultValue`s of `Parameter`s should be either a string or null.
* `LastModifiedBy` field must be present, and (_optionally_) updated with the correct author
* If a new `Category` has been created:
   * An image with the name `{categoryname}.png` must be present under the `src/step-templates/logos` folder
   * The `switch` in the `humanize` function in [`gulpfile.babel.js`](https://github.com/OctopusDeploy/Library/blob/master/gulpfile.babel.js#L92) must have a `case` statement corresponding to it
