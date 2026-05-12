Library
=======

A repository of step templates and other community-contributed extensions to Octopus Deploy.  The website to download step templates from is [https://library.octopus.com](https://library.octopus.com).

Organization
------------

* *Step templates* are checked into `/step-templates` as raw JSON exports direct from Octopus Deploy
* The *library website* is largely under `/app`, with build artifacts at the root of the repository
* The `/tools` folder contains utilities to help with editing step templates
* The `/pr-review` folder contains a browser-only PR review tool ([Hyponome](https://octopusdeploy.github.io/Library/pr-review/)) deployed to GitHub Pages

Contributing step templates or to the website
---------------------------------------------

Read our [contributing guidelines](https://github.com/OctopusDeploy/Library/blob/master/.github/CONTRIBUTING.md) for information about contributing step templates and to the website.

Reviewing PRs
-------------

### Hyponome (recommended)

The easiest way to review a PR is in the browser using **Hyponome**, our PR review microsite:

**[https://octopusdeploy.github.io/Library/pr-review/](https://octopusdeploy.github.io/Library/pr-review/)**

Hyponome lists open pull requests on this repository and, for each changed file, shows a true side-by-side diff in a Monaco editor. For step-template JSONs it surfaces a separate tab per embedded script that actually changed in the PR — `Octopus.Action.Script.ScriptBody`, `Octopus.Action.Terraform.Template`, custom `PreDeploy`/`Deploy`/`PostDeploy` scripts, and so on — each with syntax highlighting matching the script's language. This makes script changes readable without having to mentally unescape the JSON.

It runs entirely in your browser against the public GitHub API (no sign-in, no setup). Source lives in [`/pr-review`](./pr-review/README.md); changes there auto-deploy via GitHub Pages.

### Reviewing script changes locally

If you'd rather review offline, or you're hitting the unauthenticated GitHub rate limit, the `_diff.ps1` tool extracts old and new scripts into separate files you can compare in your local diff tool:

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
