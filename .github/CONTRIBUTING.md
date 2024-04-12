Contributing step templates
---------------------------

Have a great custom step that other Octopus users will love? Here's how to get it out there! 

1. [Fork](https://github.com/OctopusDeploy/Library/fork) the Library repository
2. Clone your fork into a directory on your own machine
3. _Export_ your template from the Octopus server
4. Save the exported JSON to a file under `/step-templates`
5. Check that the `LastModifiedBy` username is one you're happy to use on the site (ideally your plain GitHub username)
6. Add Id property and set it to a GUID using the following format `abcdef00-ab00-cd00-ef00-000000abcdef`, you can use [this site](https://www.guidgen.com/) to generate one automatically
7. Optional: Assign your template to an existing category. Have a look at existing templates to find the category that matches your template. If you don't specify it your template will be assigned to 'other' category.
   - If you add a new category, make sure that you add an icon in `.png` format with a size of 200x200px to the `logos` folder with the same name as your category. Also, the `switch` in the `humanize` function in [`gulpfile.babel.js`](https://github.com/OctopusDeploy/Library/blob/master/gulpfile.babel.js#L92) must have a `case` statement corresponding to it.
8. If you're updating an existing step template, make sure the `Version` property is incremented (e.g. by 1). If the `Version` doesn't change then the [Community Library Integration](http://docs.octopusdeploy.com/display/OD/Step+Templates#StepTemplates-TheCommunityLibrary) in Octopus won't see your changes.
9. Commit and push your changes to your fork
10. View your fork in GitHub to create a _pull request_

Someone from the Octopus team will review your request and help to make the step consistent with the others in the library. Once it's ready we'll merge it into the main repository and publish it to [the library site](http://library.octopusdeploy.com).

**Note**: If you're editing an existing template we've got a tool you can use to help with packing and unpacking the scripts stored in the step template `*.json` file.

* To unpack the step template scripts into separate files alongside the main step template file, run `powershell .\tools\_unpack.ps1`.
* You can then edit the `*.ps1` files in the `.\step-templates` folder using your favourite PowerShell editor.
* To pack the step template script files back into the main step template, run `powershell .\tools\_pack.ps1`. 

Here's a **checklist** to consider:

* Is the template a minor variation on an existing one? If so, please consider improving the existing template if possible.
* Is the name of the template consistent with the examples already in the library, in style ("Noun - Verb"), layout and casing?
* Are all parameters in the template consistent with the examples here, including help text documented with Markdown?
* **To minimize the risk of step template parameters clashing with other variables in a project that uses the step template, ensure that you prefix your parameter names (e.g. an abbreviated name for the step template or the category of the step template**
* Is the description of the template complete, correct Markdown?
* Is the `.json` filename consistent with the name of the template?
* Do scripts in the template validate required arguments and fail by returning a non-zero exit code when things go wrong?
* Do scripts in the template produce worthwhile status messages as they execute?
* Are you happy to contribute your template under the terms of the [license](https://github.com/OctopusDeploy/Library/blob/master/LICENSE.txt)? If you produced the template while working for your employer please obtain written permission from them before submitting it here.
* Are the default values of parameters validly applicable in other user's environments? Don't use the default values as examples if the user will have to change them
* For how to deal with parameters and testing take a look at the article [Making great Octopus PowerShell step templates](https://www.daniellittle.xyz/making-great-octopus-powershell-step-templates/)
* For another example of how to test your step template script body before submitting a PR take a look at this [gist](https://gist.github.com/JCapriotti/45639e06ba777ee974b1)
* Does the step template require extra software to work?  If possible, include the download logic in the step template itself.  If that is not possible, add the instructions to the `Description` field in the step template.
* Does the step template "just work?" In other words, after the initial scaffolding (installing a CLI for example), could anyone run the step template in a deployment and have it perform the desired action?  Or, would a person need to dig into the step template to find out how it works?  Does someone need to manually perform additional steps post-deployment to fully utilize the functionality?

If you need help, feedback or a sanity check before investing time in a contribution, feel free to raise an issue on the tracker to discuss your idea first.

Licensing
---------

The entire library is covered by [this Apache 2.0 license](https://github.com/OctopusDeploy/Library/blob/master/LICENSE.txt). [This site](http://choosealicense.com/licenses/apache-2.0/) provides a good explanation of what this license provides for you as a contributor. By contributing to this library:

* You will be asked to sign our [Contributor License Agreement (CLA)](https://en.wikipedia.org/wiki/Contributor_License_Agreement) which at the time of writing was [v1.0](https://gist.github.com/PaulStovell/568affdef31fda72d4302615ae9bcbe2). This basically allows us to accept your contribution for which you are claiming full ownership, and then relicense it under [this Apache 2.0 license](https://github.com/OctopusDeploy/Library/blob/master/LICENSE.txt). We cannot accept your contribution without your consent, nor share it with anyone else.
* Your contribution is automatically covered by [this Apache 2.0 license](https://github.com/OctopusDeploy/Library/blob/master/LICENSE.txt) without requiring a header in each file.
* Your contribution is attributed to you (and your organisation) via commits and pull-requests.
* State changes are tracked automatically via commits and pull-requests.

Contributing to the website
---------------------------

We also accept contributions to improve the [library.octopusdeploy.com](http://library.octopusdeploy.com) site. The process of contributing is similar to the process outlined for step templates above.

#### Get started

##### Pre-requisites

To build the library site you need to have `nodejs` installed on your system.

Run the setup job to install `gulp` globally and install the npm dependencies:

```
npm run setup
```

Congratulations, you are now ready to build and test the site locally.

##### Building and testing the site

From the root of the repository, run the following command: 

```
gulp build
```

This will build a debuggable version of the library site and output it to `./build/`. To test the site, run the following command:

```
cd build
node server.js
```

This will start the `express` server and you can browse the site at the following URL `http://localhost:9000`. 

While developing you can run the site in development mode so that as you make changes to the code your browser will refresh to reflect the changes you just made. To run the site in development mode, run the following command:

```
gulp watch
```

This will start a `LiveServer` that is used as a proxy for the `express` server running on `http://localhost:9000` and `gulp` will watch for changes and when detected, refresh your browser window.

You can also test the site in `production` mode. Run the following command to build the site in `production` mode:

```
gulp --production
```

This will minify/uglify/concat the js/css files and output it to `./dist/`. To test the site, run the following command:

```
cd dist
node dist/server.js
```

Once you are happy with your changes, push them to your fork and create a pull request from the GitHub site.

### Code Cleanup
To keep everything nice and tidy, [ESLint](https://eslint.org/) and [Prettier](https://prettier.io/) are used to enforce a consistent code styling throughout the project. If you are using VSCode, install the ESLint extension and make sure the following setting is enabled:
```
{
  "editor.codeActionsOnSave": {
      "source.fixAll.eslint": true
  }
}
```

You can also run `npm run lint:fix` to solve any errors and warnings.
