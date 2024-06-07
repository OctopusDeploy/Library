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
import jsonlint from "gulp-jsonlint";

const sass = gulpSass(dartSass);
const clientDir = "app";
const serverDir = "server";

const buildDir = "build";
const publishDir = "dist";

const $ = gulpLoadPlugins({
  rename: {
    "gulp-expect-file": "expect",
  },
});

const reload = browserSync.reload;
const argv = yargs.argv;

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
      .pipe(reload({ stream: true, once: true }))
      .pipe($.eslint(options))
      .pipe($.eslint.format("compact"))
      .pipe($.if(!browserSync.active, $.eslint.failOnError()));
  };
}

gulp.task("lint:client", lint(`${clientDir}/**/*.jsx`));
gulp.task("lint:server", lint(`./${serverDir}/server.js`));
gulp.task("lint:step-templates", () => {
  return gulp
    .src("./step-templates/*.json")
    .pipe($.expect({ errorOnFailure: true, silent: true }, glob.sync("step-templates/*.json")))
    .pipe(jsonlint())
    .pipe(jsonlint.failOnError())
    .pipe(jsonlint.reporter());
});

gulp.task(
  "tests",
  gulp.series("lint:step-templates", () => {
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
  })
);

function humanize(categoryId) {
  switch (categoryId) {
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
    var pathParts = file.path.split("\\");
    var fileName = pathParts[pathParts.length - 1];

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
      var logo = fs.readFileSync("./step-templates/logos/" + categoryId + ".png");
      template.Logo = Buffer.from(logo).toString("base64");
    }

    file.contents = Buffer.from(JSON.stringify(template));

    cb(null, file);
  });
}

gulp.task(
  "step-templates",
  gulp.series("tests", () => {
    return gulp
      .src("./step-templates/*.json")
      .pipe(provideMissingData())
      .pipe(concat("step-templates.json", { newLine: "," }))
      .pipe(insert.wrap('{"items": [', "]}"))
      .pipe(argv.production ? gulp.dest(`${publishDir}/app/services`) : gulp.dest(`${buildDir}/app/services`));
  })
);

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

    browserSync.init(null, {
      proxy: "http://localhost:9000",
    });

    gulp.watch(`${clientDir}/**/*.jade`, gulp.series("build:client"));
    gulp.watch(`${clientDir}/**/*.jsx`, gulp.series("scripts", "copy:app"));
    gulp.watch(`${clientDir}/content/styles/**/*.scss`, gulp.series("styles:client"));
    gulp.watch("step-templates/*.json", gulp.series("step-templates"));

    gulp.watch(`${buildDir}/**/*.*`).on("change", reload);
  })
);

gulp.task("default", gulp.series("clean", "build"));
