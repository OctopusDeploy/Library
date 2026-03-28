Library
=======

A repository of step templates and other community-contributed extensions to Octopus Deploy.  The website to download step templates from is [https://library.octopus.com](https://library.octopus.com).

Organization
------------

* *Step templates* are authored under `/src/step-templates`
* Generated compatibility JSON for the website and Octopus imports is written to `/step-templates`
* The *library website* is largely under `/app`, with build artifacts at the root of the repository
* The `/tools` folder contains the existing pack/unpack scripts plus the source-first generation helpers

Source Layout
-------------

The source-of-truth format for templates lives under `/src/step-templates`:

* `/src/step-templates/<template>/metadata.json`
* `/src/step-templates/<template>/scriptbody.ps1|sh|py`
* `/src/step-templates/<template>/predeploy.ps1`
* `/src/step-templates/<template>/deploy.ps1`
* `/src/step-templates/<template>/postdeploy.ps1`
* `/src/step-templates/logos`
* `/src/step-templates/tests`

`metadata.json` keeps the exported template metadata and uses placeholders for script-backed properties. The real script text lives in sibling files so normal GitHub diffs stay readable.

Contributing step templates or to the website
---------------------------------------------

Read our [contributing guidelines](https://github.com/OctopusDeploy/Library/blob/master/.github/CONTRIBUTING.md) for information about contributing step templates and to the website.

Reviewing PRs
-------------

### Reviewing script changes

For migrated templates, review the files under `/src/step-templates/<template>/` directly. Script changes now appear as normal file diffs instead of escaped JSON string blobs.

### Checklist

When reviewing a PR, keep the following things in mind:
* `Id` should be a **GUID** that is not `00000000-0000-0000-0000-000000000000`
* `Version` should be incremented, otherwise the integration with Octopus won't update the step template correctly
* Parameter names should not start with `$`
* The `DefaultValue`s of `Parameter`s should be either a string or null.
* `LastModifiedBy` field must be present, and (_optionally_) updated with the correct author
* Generated JSON under `/step-templates` should not be hand-edited or committed
* If a new `Category` has been created:
   * An image with the name `{categoryname}.png` must be present under the `src/step-templates/logos` folder
   * The `switch` in the `humanize` function in [`gulpfile.babel.js`](https://github.com/OctopusDeploy/Library/blob/master/gulpfile.babel.js#L92) must have a `case` statement corresponding to it
