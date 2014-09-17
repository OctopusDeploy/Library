Library
=======

A repository of step templates and other community-contributed extensions to Octopus Deploy.

Organization
------------

* *Step templates* are checked into `/step-templates` as raw JSON exports direct from Octopus Deploy
* The *library website* is largely under `/app`, with build artifacts at the root of the repository

Contributing step templates
---------------------------

Have a great custom step that other Octopus users will love? Here's how to get it out there!

1. [Fork](https://github.com/OctopusDeploy/Library/fork) the Library repository
2. Clone your fork into a directory on your own machine
3. _Export_ your template from the Octopus server
4. Save the exported JSON to a file under `/step-templates`
5. Check that the `LastModifiedBy` username is one you're happy to use on the site (ideally your plain GitHub username)
6. Commit and push your changes to your fork
7. View your fork in GitHub to create a _pull request_

Someone from the Octopus team will review your request and help to make the step consistent with the others in the library. Once it's ready we'll merge it into the main repository and publish it to [the library site](http://library.octopusdeploy.com).

Here's a **checklist** to consider:

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

If you need help, feedback or a sanity check before investing time in a contribution, feel free to raise an issue on the tracker to discuss your idea first.

Contributing to the website
---------------------------

We also accept contributions to improve the [library.octopusdeploy.com](http://library.octopusdeploy.com) site. The process of contributing is similar to the process outlined for step templates above. There's some more information on working with the code on the [wiki](https://github.com/OctopusDeploy/Library/wiki/BuildingTheSite).
