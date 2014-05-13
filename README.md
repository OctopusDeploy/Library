Library
=======

A repository of step templates and other community-contributed extensions to Octopus Deploy.

Organization
------------

* *Step templates* are checked into `/step-templates` as raw JSON exports direct from Octopus Deploy
* The *library website* is largely under `/app`, with build artifacts at the root of the repository

Building the site
-----------------

You'll need Node.js installed on your system.

First, the globally-installed build tools if you don't have them already:

```
npm install gulp -g
npm install bower -g
```

Then, from the root of the repository, restore the build-time and run-time dependencies:

```
npm install
bower install
```

To build the site:

```
gulp
```

This will output:

* `build/` - a debuggable version of the site
* `dist/` - a minified, hash-rev'd build of the same

As you work locally you probably want to have your changes built automatically; since some parts of the site can't be served from the filesystem (a `.swf` component currently) you will also want to host the site in a local webserver.

Run:

```
gulp watch
```

Then open [http://localhost:4000](http://localhost:4000) to enjoy this convenience.

