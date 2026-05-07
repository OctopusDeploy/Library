"use strict";

import gulp from "gulp";
import log from "fancy-log";
import gulpLoadPlugins from "gulp-load-plugins";
import browserSync from "browser-sync";
import LiveServer from "gulp-live-server";
import gulpSass from "gulp-sass";
import dartSass from "sass";
import concat from "gulp-concat";
import insert from "gulp-insert";
import del from "del";
import source from "vinyl-source-stream";
import buffer from "vinyl-buffer";
import babelify from "babelify";
import reactify from "reactify";
import browserify from "browserify";
import uglify from "gulp-uglify-es";
import postcss from "gulp-postcss";
import cssnano from "cssnano";
import rename from "gulp-rename";
import sourcemaps from "gulp-sourcemaps";
import inject from "gulp-inject";
import yargs from "yargs";
import rev from "gulp-rev";
import glob from "glob";
import envify from "envify/custom";
import jasmine from "gulp-jasmine";
import jasmineReporters from "jasmine-reporters";
import jasmineTerminalReporter from "jasmine-terminal-reporter";
import eventStream from "event-stream";
import fs from "fs";
import http from "http";
import https from "https";
import jsonlint from "gulp-jsonlint";
import path from "path";
import { execFileSync, spawn } from "child_process";

const sass = gulpSass(dartSass);
const clientDir = "app";
const serverDir = "server";

const buildDir = "build";
const publishDir = "dist";
const sourceStepTemplatesDir = "src/step-templates";
const sourceFirstTemplateFilter = process.env.SOURCE_FIRST_TEMPLATE_FILTER
  ? new Set(
      process.env.SOURCE_FIRST_TEMPLATE_FILTER.split(",")
        .map((value) => value.trim())
        .filter(Boolean)
    )
  : null;
const scriptDefinitions = [
  {
    sourceBaseName: "scriptbody",
    sourceExtensions: [".ps1", ".sh", ".py"],
    propertyName: "Octopus.Action.Script.ScriptBody",
    legacyBaseName: "ScriptBody",
  },
  {
    sourceBaseName: "predeploy",
    sourceExtensions: [".ps1"],
    propertyName: "Octopus.Action.CustomScripts.PreDeploy.ps1",
    legacyBaseName: "PreDeploy",
  },
  {
    sourceBaseName: "deploy",
    sourceExtensions: [".ps1"],
    propertyName: "Octopus.Action.CustomScripts.Deploy.ps1",
    legacyBaseName: "Deploy",
  },
  {
    sourceBaseName: "postdeploy",
    sourceExtensions: [".ps1"],
    propertyName: "Octopus.Action.CustomScripts.PostDeploy.ps1",
    legacyBaseName: "PostDeploy",
  },
];

const $ = gulpLoadPlugins({
  rename: {
    "gulp-expect-file": "expect",
  },
});

const reload = browserSync.reload;
const argv = yargs.argv;

function isDirectory(targetPath) {
  return fs.existsSync(targetPath) && fs.statSync(targetPath).isDirectory();
}

function ensureDirectory(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function listMigratedTemplates() {
  if (!isDirectory(sourceStepTemplatesDir)) {
    return [];
  }

  return fs
    .readdirSync(sourceStepTemplatesDir)
    .filter((entry) => !["logos", "tests"].includes(entry))
    .filter((entry) => isDirectory(path.join(sourceStepTemplatesDir, entry)))
    .filter((entry) => fs.existsSync(path.join(sourceStepTemplatesDir, entry, "metadata.json")))
    .filter((entry) => !sourceFirstTemplateFilter || sourceFirstTemplateFilter.has(entry))
    .sort();
}

function getLegacyJsonPath(templateName) {
  return path.join("step-templates", `${templateName}.json`);
}

function getSourceTemplateDirectory(templateName) {
  return path.join(sourceStepTemplatesDir, templateName);
}

function getLegacySidecarFileName(templateName, sourceFileName, definition) {
  const extension = path.extname(sourceFileName);

  return `${templateName}.${definition.legacyBaseName}${extension}`;
}

function runPack(templateName) {
  execFileSync(process.env.PWSH_PATH || "pwsh", ["-NoProfile", "-File", path.join("tools", "_pack.ps1"), "-SearchPattern", templateName], {
    cwd: process.cwd(),
    stdio: "inherit",
  });
}

function cleanGeneratedSidecars(templateName) {
  for (const definition of scriptDefinitions) {
    for (const extension of definition.sourceExtensions) {
      const sidecarPath = path.join("step-templates", getLegacySidecarFileName(templateName, `${definition.sourceBaseName}${extension}`, definition));
      if (fs.existsSync(sidecarPath)) {
        fs.rmSync(sidecarPath, { force: true });
      }
    }
  }
}

function materializeLegacyTemplate(templateName) {
  const sourceDirectory = getSourceTemplateDirectory(templateName);
  const metadataPath = path.join(sourceDirectory, "metadata.json");

  if (!fs.existsSync(metadataPath)) {
    return false;
  }

  ensureDirectory("step-templates");
  fs.copyFileSync(metadataPath, getLegacyJsonPath(templateName));

  for (const definition of scriptDefinitions) {
    for (const extension of definition.sourceExtensions) {
      const sourceFileName = `${definition.sourceBaseName}${extension}`;
      const sourceFilePath = path.join(sourceDirectory, sourceFileName);

      if (!fs.existsSync(sourceFilePath)) {
        continue;
      }

      const legacySidecarPath = path.join("step-templates", getLegacySidecarFileName(templateName, sourceFileName, definition));
      fs.copyFileSync(sourceFilePath, legacySidecarPath);
      break;
    }
  }

  return true;
}

function generateMigratedTemplate(templateName) {
  if (!materializeLegacyTemplate(templateName)) {
    return false;
  }

  try {
    runPack(templateName);
  } finally {
    cleanGeneratedSidecars(templateName);
  }

  return true;
}

function generateAllMigratedTemplates() {
  const templateNames = listMigratedTemplates();

  if (templateNames.length === 0) {
    return false;
  }

  templateNames.forEach((templateName) => {
    generateMigratedTemplate(templateName);
  });

  return true;
}

function getChangedSourcePathType(changedPath) {
  const absolutePath = path.resolve(changedPath);
  const relativePath = path.relative(path.resolve(sourceStepTemplatesDir), absolutePath);

  if (relativePath.startsWith("..")) {
    return { type: "outside" };
  }

  const [firstSegment] = relativePath.split(path.sep).filter(Boolean);
  if (!firstSegment) {
    return { type: "all" };
  }

  if (firstSegment === "logos") {
    return { type: "logos" };
  }

  if (firstSegment === "tests") {
    return { type: "tests" };
  }

  return { type: "template", templateName: firstSegment };
}

function openBrowser(url) {
  if (process.env.CI) {
    return;
  }

  if (process.platform === "darwin") {
    spawn("open", [url], { detached: true, stdio: "ignore" }).unref();
    return;
  }

  if (process.platform === "win32") {
    spawn("cmd", ["/c", "start", "", url], { detached: true, stdio: "ignore" }).unref();
    return;
  }

  spawn("xdg-open", [url], { detached: true, stdio: "ignore" }).unref();
}

function waitForServer(url, { timeoutMs = 10000, pollIntervalMs = 200 } = {}) {
  const parsedUrl = new URL(url);
  const client = parsedUrl.protocol === "https:" ? https : http;
  const startedAt = Date.now();

  return new Promise((resolve) => {
    function tryConnect() {
      const request = client.get(url, (response) => {
        response.resume();
        resolve(true);
      });

      request.on("error", () => {
        if (Date.now() - startedAt >= timeoutMs) {
          resolve(false);
          return;
        }

        setTimeout(tryConnect, pollIntervalMs);
      });

      request.setTimeout(pollIntervalMs, () => {
        request.destroy(new Error("timeout"));
      });
    }

    tryConnect();
  });
}

const vendorStyles = [
  "node_modules/font-awesome/css/font-awesome.min.css",
  "node_modules/font-awesome/css/font-awesome.css.map",
  "node_modules/font-awesome/fonts/fontawesome*{.eot,.svg,.ttf,.woff,.woff2,.otf}",
  "node_modules/normalize.css/normalize.css",
];

gulp.task("clean", () => {
  return del([`${publishDir}`, `${buildDir}`, `${clientDir}/data/*.json`]);
});

function lint(files, options = {}) {
  return () => {
    return gulp
      .src(files)
      .pipe($.eslint(options))
      .pipe($.eslint.format("compact"))
      .pipe($.if(!browserSync.active, $.eslint.failOnError()));
  };
}

gulp.task("lint:client", lint(`${clientDir}/**/*.jsx`));
gulp.task("lint:server", lint(`./${serverDir}/server.js`));
gulp.task("prepare:step-templates", (done) => {
  generateAllMigratedTemplates();
  done();
});

gulp.task("lint:step-templates", () => {
  return gulp
    .src("./step-templates/*.json")
    .pipe($.expect({ errorOnFailure: true, silent: true }, glob.sync("step-templates/*.json")))
    .pipe(jsonlint())
    .pipe(jsonlint.failOnError())
    .pipe(jsonlint.reporter());
});

gulp.task("test:step-templates", () => {
  return (
    gulp
      .src("./spec/*-tests.js")
      // gulp-jasmine works on filepaths so you can't have any plugins before it
      .pipe(
        jasmine({
          includeStackTrace: false,
          reporter: [new jasmineReporters.JUnitXmlReporter(), process.env.TEAMCITY_VERSION ? new jasmineReporters.TeamCityReporter() : new jasmineTerminalReporter()],
        })
      )
      .on("error", function () {
        process.exit(1);
      })
  );
});

gulp.task("tests", gulp.series("prepare:step-templates", "lint:step-templates", "test:step-templates"));

function humanize(categoryId) {
  switch (categoryId) {
    case "1password-connect":
      return "1Password Connect";
    case "amazon-chime":
      return "Amazon Chime";
    case "ansible":
      return "Ansible";
    case "apexsql":
      return "ApexSQL";
    case "apollo":
      return "Apollo GraphQL";
    case "argo":
      return "Argo";
    case "aspnet":
      return "ASP.NET";
    case "aws":
      return "AWS";
    case "azure-devops":
      return "Azure DevOps";
    case "azure-keyvault":
      return "Azure Key Vault";
    case "azure-site-extensions":
      return "Azure Site Extensions";
    case "azureFunctions":
      return "Azure Functions";
    case "bitwarden":
      return "Bitwarden";
    case "cassandra":
      return "Cassandra";
    case "chef":
      return "Chef";
    case "clickonce":
      return "ClickOnce";
    case "cyberark":
      return "CyberArk";
    case "dll":
      return "dll";
    case "dlm":
      return "dlm";
    case "dotnetcore":
      return ".NET Core";
    case "edgecast":
      return "EdgeCast";
    case "elmah":
      return "ELMAH";
    case "email":
      return "Email";
    case "entityframework":
      return "Entity Framework";
    case "event-tracing":
      return "Event Tracing for Windows";
    case "filesystem":
      return "File System";
    case "firebase":
      return "Firebase";
    case "flyway":
      return "Flyway";
    case "ghostinspector":
      return "Ghost Inspector";
    case "github":
      return "GitHub";
    case "gitlab":
      return "GitLab";
    case "google-chat":
      return "Google Chat";
    case "google-cloud":
      return "Google Cloud";
    case "grate":
      return "Grate";
    case "hashicorp-vault":
      return "HashiCorp Vault";
    case "hipchat":
      return "HipChat";
    case "hockeyapp":
      return "HockeyApp";
    case "hosts-file":
      return " Hosts File";
    case "http":
      return "HTTP";
    case "iis":
      return "IIS";
    case "jira":
      return "JIRA";
    case "json":
      return "JSON";
    case "jwt":
      return "JWT";
    case "k8s":
      return "Kubernetes";
    case "keeper-secretsmanager":
      return "Keeper Secrets Manager";
    case "launchdarkly":
      return "LaunchDarkly";
    case "lets-encrypt":
      return "Lets Encrypt";
    case "linux":
      return "Linux";
    case "liquibase":
      return "Liquibase";
    case "mabl":
      return "mabl";
    case "mariadb":
      return "MariaDB";
    case "microsoft-teams":
      return "Microsoft Teams";
    case "microsoft-power-automate":
      return "Microsoft Power Automate";
    case "mongodb":
      return "MongoDB";
    case "mulesoft":
      return "Mulesoft";
    case "mysql":
      return "MySQL";
    case "netscaler":
      return "NetScaler";
    case "newrelic":
      return "New Relic";
    case "nunit":
      return "NUnit";
    case "opslevel":
      return "OpsLevel";
    case "pagerduty":
      return "PagerDuty";
    case "postgresql":
      return "PostgreSQL";
    case "pulumi":
      return "Pulumi";
    case "rabbitmq":
      return "RabbitMQ";
    case "ravendb":
      return "RavenDB";
    case "readyroll":
      return "ReadyRoll";
    case "redgate":
      return "Redgate";
    case "roundhouse":
      return "RoundhousE";
    case "sbom":
      return "SBOM";
    case "sharepoint":
      return "SharePoint";
    case "snowflake":
      return "Snowflake";
    case "solarwinds":
      return "SolarWinds";
    case "sql":
      return "SQL Server";
    case "ssl":
      return "SSL";
    case "statuspage":
      return "StatusPage";
    case "swaggerhub":
      return "SwaggerHub";
    case "statuscake":
      return "StatusCake";
    case "teamcity":
      return "TeamCity";
    case "terraform":
      return "Terraform";
    case "testery":
      return "Testery";
    case "tomcat":
      return "Tomcat";
    case "twilio":
      return "Twilio";
    case "victorops":
      return "VictorOps";
    case "webdeploy":
      return "Web Deploy";
    case "xml":
      return "XML";
    case "xunit":
      return "xUnit";
    case "databricks":
      return "Databricks";
    case "rnhub":
      return "RnHub";
    case "venafi":
      return "Venafi";
    case "proxmox":
      return "Proxmox";
    default:
      return categoryId[0].toUpperCase() + categoryId.substr(1).toLowerCase();
  }
}

function provideMissingData() {
  return eventStream.map(function (file, cb) {
    var fileContent = file.contents.toString();
    var template = JSON.parse(fileContent);
    var fileName = path.basename(file.path);
    var templateName = path.basename(file.path, ".json");

    if (!template.HistoryUrl) {
      template.HistoryUrl = "https://github.com/OctopusDeploy/Library/commits/master/step-templates/" + fileName;
    }

    if (!template.Website) {
      template.Website = "/step-templates/" + template.Id;
    }

    var categoryId = template.Category;
    if (!categoryId) {
      categoryId = "other";
    }

    categoryId = categoryId.toLowerCase();

    template.Category = humanize(categoryId);

    if (!template.Logo) {
      var sourceLogoPath = "./src/step-templates/" + templateName + "/logo.png";
      var legacyLogoPath = "./step-templates/logos/" + categoryId + ".png";
      var logo = fs.readFileSync(fs.existsSync(sourceLogoPath) ? sourceLogoPath : legacyLogoPath);
      template.Logo = Buffer.from(logo).toString("base64");
    }

    file.contents = Buffer.from(JSON.stringify(template));

    cb(null, file);
  });
}

gulp.task("step-templates:data", () => {
  return gulp
    .src("./step-templates/*.json")
    .pipe(provideMissingData())
    .pipe(concat("step-templates.json", { newLine: "," }))
    .pipe(insert.wrap('{"items": [', "]}"))
    .pipe(argv.production ? gulp.dest(`${publishDir}/app/services`) : gulp.dest(`${buildDir}/app/services`));
});

gulp.task("step-templates", gulp.series("tests", "step-templates:data"));

gulp.task("styles:vendor", () => {
  return gulp.src(vendorStyles, { base: "node_modules/" }).pipe(argv.production ? gulp.dest(`${publishDir}/public/styles/vendor`) : gulp.dest(`${buildDir}/public/styles/vendor`));
});

gulp.task("styles:client", () => {
  let postCssPlugins = [cssnano];
  return gulp
    .src(`${clientDir}/content/styles/main.scss`)
    .pipe(sass().on("error", sass.logError))
    .pipe($.if(argv.production, sourcemaps.init({ loadMaps: true })))
    .pipe($.if(argv.production, postcss(postCssPlugins)))
    .on("error", log.error)
    .pipe($.if(argv.production, rename({ suffix: ".min" })))
    .pipe($.if(argv.production, rev()))
    .pipe($.if(argv.production, sourcemaps.write(".")))
    .pipe(argv.production ? gulp.dest(`${publishDir}/public/styles`) : gulp.dest(`${buildDir}/public/styles`));
});

gulp.task("images", () => {
  return gulp.src(`${clientDir}/content/images/**/*{.png,.gif,.jpeg,.jpg,.bmp}`).pipe(argv.production ? gulp.dest(`${publishDir}/public/images`) : gulp.dest(`${buildDir}/public/images`));
});

gulp.task("copy:app", () => {
  return gulp.src(`${clientDir}/**/*{.jsx,.js}`).pipe(argv.production ? gulp.dest(`${publishDir}/app`) : gulp.dest(`${buildDir}/app`));
});

gulp.task("copy:configs", () => {
  return gulp.src(["./package.json", "./package-lock.json", "./web.config", "./IISNode.yml"]).pipe(argv.production ? gulp.dest(`${publishDir}`) : gulp.dest(`${buildDir}`));
});

gulp.task(
  "scripts",
  gulp.series("lint:client", () => {
    return browserify({
      entries: `./${clientDir}/Browser.jsx`,
      extensions: [".jsx", ".js"],
      debug: true,
    })
      .transform(babelify)
      .transform(reactify)
      .transform(envify({ _: "purge", NODE_ENV: argv.production ? "production" : "development" }), { global: true })
      .bundle()
      .pipe(source("app.js"))
      .pipe(buffer())
      .pipe($.if(argv.production, sourcemaps.init({ loadMaps: true })))
      .pipe($.if(argv.production, uglify()))
      .on("error", log.error)
      .pipe($.if(argv.production, rename({ suffix: ".min" })))
      .pipe($.if(argv.production, rev()))
      .pipe($.if(argv.production, sourcemaps.write(".")))
      .pipe(argv.production ? gulp.dest(`${publishDir}/public/scripts`) : gulp.dest(`${buildDir}/public/scripts`));
  })
);

gulp.task(
  "build:client",
  gulp.series("step-templates", "copy:app", "scripts", "styles:client", "styles:vendor", "images", () => {
    let vendorSources = gulp.src(vendorStyles, { base: "node_modules/" });

    let sources = argv.production
      ? gulp.src([`${publishDir}/public/**/*.js`, `${publishDir}/public/**/*.css*`, `!${publishDir}/public/**/vendor{,/**}`], { read: false })
      : gulp.src([`${buildDir}/public/**/*.js`, `${buildDir}/public/**/*.css*`, `!${buildDir}/public/**/vendor{,/**}`], { read: false });

    return gulp
      .src(`${serverDir}/views/index.pug`)
      .pipe(inject(vendorSources, { relative: false, name: "vendor", ignorePath: "node_modules", addPrefix: "styles/vendor" }))
      .pipe(inject(sources, { relative: false, ignorePath: `${argv.production ? `${publishDir}` : `${buildDir}`}/public` }))
      .pipe(argv.production ? gulp.dest(`${publishDir}/views`) : gulp.dest(`${buildDir}/views`));
  })
);

gulp.task(
  "build:server",
  gulp.series("lint:server", () => {
    return gulp
      .src([`./${serverDir}/server.js`])
      .pipe($.babel())
      .pipe(argv.production ? gulp.dest(`${publishDir}`) : gulp.dest(`${buildDir}`));
  })
);

gulp.task("build", gulp.parallel("build:server", "build:client", "copy:configs"));

gulp.task(
  "watch",
  gulp.series("clean", "build", () => {
    process.chdir(`${buildDir}`);
    let server = LiveServer(`server.js`);
    server.start();
    process.chdir(`../`);

    browserSync.init(
      null,
      {
        proxy: "http://localhost:9000",
        open: false,
      },
      () => {
        waitForServer("http://localhost:9000").then((isReady) => {
          if (isReady) {
            openBrowser("http://localhost:9000");
            return;
          }

          log.warn("Timed out waiting for http://localhost:9000, skipping automatic browser launch.");
        });
      }
    );

    function reloadServer(done) {
      process.chdir(`${buildDir}`);
      server.start();
      process.chdir(`../`);
      done();
    }

    gulp.watch(`${clientDir}/**/*.jade`, gulp.series("build:client"));
    gulp.watch(`${clientDir}/**/*.jsx`, gulp.series("scripts", "copy:app", reloadServer));
    gulp.watch(`${clientDir}/content/styles/**/*.scss`, gulp.series("styles:client"));
    gulp.watch("step-templates/*.json", gulp.series("step-templates:data"));
    gulp.watch(`${sourceStepTemplatesDir}/**/*`).on("all", (eventName, changedPath) => {
      const change = changedPath ? getChangedSourcePathType(changedPath) : { type: "all" };

      if (change.type === "template") {
        generateMigratedTemplate(change.templateName);
      } else if (change.type === "logos" || change.type === "all") {
        generateAllMigratedTemplates();
      } else if (change.type === "outside" || change.type === "tests") {
        return;
      }

      gulp.series("step-templates:data")((error) => {
        if (error) {
          log.error(error);
          return;
        }

        reload();
      });
    });

    gulp.watch(`${buildDir}/**/*.*`).on("change", reload);
  })
);

gulp.task("default", gulp.series("clean", "build"));
