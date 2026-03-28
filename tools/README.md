Tools
=====

This folder contains both the legacy step-template pack/unpack scripts and the
new helper scripts used during the source-first migration.

Legacy scripts that must remain behaviorally unchanged
------------------------------------------------------

These are the canonical scripts for producing byte-identical packed output:

* `_pack.ps1`
* `_unpack.ps1`
* `Converter.ps1`
* `StepTemplatePacker/`

Migration and generation helpers must wrap these scripts instead of modifying
them directly.

Permanent helper scripts
------------------------

These support the post-migration source-first workflow:

* `generate-step-templates.js`
* `source-step-template-lib.js`

They read authored content from `/src/step-templates`, materialize the
temporary legacy sidecar layout expected by the unchanged packer, invoke the
legacy pack flow, and then clean up the temporary sidecars.

Migration-only helper scripts
-----------------------------

These exist only to support the repository migration and should be removable
after the migration is complete:

* `migration-prepare-step-template.js`
* `migration-verify-step-template.js`

They handle `.json.orig` creation, `git mv` preparation, placeholder updates,
and byte-for-byte validation of regenerated output.

Helpers to evaluate for removal later
-------------------------------------

These are retained for now but should be reviewed once the migration is proven:

* `_diff.ps1`

After templates are authored as normal files under `/src/step-templates`, GitHub
diffs should make `_diff.ps1` unnecessary for most review workflows.
