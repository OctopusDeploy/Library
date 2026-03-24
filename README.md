Library
=======

A repository of step templates and other community-contributed extensions to Octopus Deploy.  The website to download step templates from is [https://library.octopus.com](https://library.octopus.com).

Organization
------------

* *Step templates* are checked into `/step-templates` as raw JSON exports direct from Octopus Deploy
* The *library website* is largely under `/app`, with build artifacts at the root of the repository
* The `/tools` folder contains utilities to help with editing step templates

Contributing step templates or to the website
---------------------------------------------

Read our [contributing guidelines](https://github.com/OctopusDeploy/Library/blob/master/.github/CONTRIBUTING.md) for information about contributing step templates and to the website.

Reviewing PRs
-------------

### Reviewing script changes

Step template JSON files embed scripts as single-line escaped strings, making diffs hard to read. Use the `_diff.ps1` tool to extract old and new scripts into separate files you can compare in your diff tool:

```powershell
# Compare ScriptBody against previous commit
.\tools\_diff.ps1 -SearchPattern "template-name"

# Compare against a specific commit or branch
.\tools\_diff.ps1 -SearchPattern "template-name" -CompareWith "master"
```

This outputs readable files to `diff-output/`:
- `template-name.ScriptBody.old.ps1`
- `template-name.ScriptBody.new.ps1`

Also handles `PreDeploy`, `Deploy`, and `PostDeploy` custom scripts if present.

### Checklist

When reviewing a PR, keep the following things in mind:
* `Id` should be a **GUID** that is not `00000000-0000-0000-0000-000000000000`
* `Version` should be incremented, otherwise the integration with Octopus won't update the step template correctly
* Parameter names should not start with `$`
* The `DefaultValue`s of `Parameter`s should be either a string or null.
* `LastModifiedBy` field must be present, and (_optionally_) updated with the correct author
* If a new `Category` has been created:
   * An image with the name `{categoryname}.png` must be present under the `step-templates/logos` folder
   * The `switch` in the `humanize` function in [`gulpfile.babel.js`](https://github.com/OctopusDeploy/Library/blob/master/gulpfile.babel.js#L92) must have a `case` statement corresponding to it
