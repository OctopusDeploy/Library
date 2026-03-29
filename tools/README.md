Tools
=====

This folder contains both the legacy step-template pack/unpack scripts and the
helper scripts used by the source-first workflow.

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

Retained legacy utilities
-------------------------

These remain for compatibility and round-trip fidelity:

* `_diff.ps1`
* `_pack.ps1`
* `_unpack.ps1`
* `Converter.ps1`
* `StepTemplatePacker/`
