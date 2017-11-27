### Step template guidelines

* Is the template a minor variation on an existing one? If so, please consider improving the existing template if possible.
* Is the name of the template consistent with the examples already in the library, in style ("Noun - Verb"), layout and casing?
* Are all parameters in the template consistent with the examples here, including help text documented with Markdown?
* Is the description of the template complete, correct Markdown?
* Is the `.json` filename consistent with the name of the template?
* Do scripts in the template validate required arguments and fail by returning a non-zero exit code when things go wrong?
* Do scripts in the template produce worthwhile status messages as they execute?
* Are you happy to contribute your template under the terms of the [license](https://github.com/OctopusDeploy/Library/blob/master/LICENSE)? If you produced the template while working for your employer please obtain written permission from them before submitting it here.
* Are the default values of parameters validly applicable in other user's environments? Don't use the default values as examples if the user will have to change them
* For how to deal with parameters and testing take a look at the article [Making great Octopus PowerShell step templates](http://www.lavinski.me/making-great-octopus-powershell-step-templates/)
* For another example of how to test your step template script body before submitting a PR take a look at this [gist](https://gist.github.com/JCapriotti/45639e06ba777ee974b1)

_Before submitting your PR, please delete everything above the line below._

---

### Step template checklist

- [ ] `Id` should be a **GUID** that is not `00000000-0000-0000-0000-000000000000`
  - **NOTE** If you are modifying an existing step template, please make sure that you **do not** modify the `Id` property *(updating the `Id` will break the Library sync functionality in Octopus)*. 
- [ ] `Version` should be incremented, otherwise the integration with Octopus won't update the step template correctly
- [ ] Parameter names should not start with `$`
- [ ] **To minimize the risk of step template parameters clashing with other variables in a project that uses the step template, ensure that you prefix your parameter names (e.g. an abbreviated name for the step template or the category of the step template**
- [ ] `LastModifiedBy` field must be present, and (_optionally_) updated with the correct author
- [ ] If a new `Category` has been created:
   - [ ] An image with the name `{categoryname}.png` must be present under the `step-templates/logos` folder
   - [ ] The `switch` in the `humanize` function in [`gulpfile.babel.js`](https://github.com/OctopusDeploy/Library/blob/master/gulpfile.babel.js#L92) must have a `case` statement corresponding to it

Fixes # . _If there is an open issue that this PR fixes add it here, otherwise just remove this line_
