'use strict';

import gulp from 'gulp';
import gutil from 'gulp-util';
import gulpLoadPlugins from 'gulp-load-plugins';
import browserSync from 'browser-sync';
import LiveServer from 'gulp-live-server';
import sass from 'gulp-sass';
import concat from 'gulp-concat';
import replace from 'gulp-replace';
import header from 'gulp-header';
import footer from 'gulp-footer';
import del from 'del';
import source from 'vinyl-source-stream';
import merge from 'merge-stream';
import buffer from 'vinyl-buffer';
import babelify from 'babelify';
import reactify from 'reactify';
import browserify from 'browserify';
import uglify from 'gulp-uglify';
import cssnano from 'gulp-cssnano';
import rename from 'gulp-rename';
import sourcemaps from 'gulp-sourcemaps';
import inject from 'gulp-inject';
import yargs from 'yargs';
import rev from 'gulp-rev';
import glob from 'glob';
import envify from 'envify/custom';
import jasmine from 'gulp-jasmine';
import jasmineReporters from 'jasmine-reporters';
import jasmineTerminalReporter from 'jasmine-terminal-reporter';
import eventStream from 'event-stream';
import {Converter} from 'csvtojson';
import fs from 'fs';
import jsonlint from 'gulp-jsonlint';

const clientDir = 'app';
const serverDir = 'server';

const buildDir = 'build';
const publishDir = 'dist';

const $ = gulpLoadPlugins({
  rename: {
    'gulp-expect-file': 'expect'
  }
});

const reload = browserSync.reload;
const argv = yargs.argv;

const vendorStyles = [
  'node_modules/font-awesome/css/font-awesome.min.css',
  'node_modules/font-awesome/css/font-awesome.css.map',
  'node_modules/font-awesome/fonts/fontawesome*{.eot,.svg,.ttf,.woff,.woff2,.otf}',
  'node_modules/normalize.css/normalize.css'
];

gulp.task('clean', () => {
  del.sync([`${publishDir}`, `${buildDir}`, `${clientDir}/data/*.json`]);
});

function lint(files, options) {
  return () => {
    return gulp.src(files)
      .pipe(reload({stream: true, once: true}))
      .pipe($.eslint(options))
      .pipe($.eslint.format('compact'))
      .pipe($.if(!browserSync.active, $.eslint.failOnError()));
  };
}

gulp.task('lint:client', lint(`${clientDir}/**/*.jsx`));
gulp.task('lint:server', lint(`./${serverDir}/server.js`));
gulp.task('lint:step-templates', () => {
  return gulp.src('./step-templates/*.json')
    .pipe($.expect({ errorOnFailure: true, silent: true }, glob.sync('step-templates/*.json')))
    .pipe(jsonlint())
    .pipe(jsonlint.failOnError())
    .pipe(jsonlint.reporter());
});

gulp.task('tests', ['lint:step-templates'], () => {
  return gulp.src('./spec/*-tests.js')
  // gulp-jasmine works on filepaths so you can't have any plugins before it
    .pipe(jasmine({
      includeStackTrace: false,
      reporter: [ 
        new jasmineReporters.JUnitXmlReporter(), 
        (process.env.TEAMCITY_VERSION 
          ? new jasmineReporters.TeamCityReporter() 
          : new jasmineTerminalReporter())
      ]
    }))
    .on('error', function(){
      process.exit(1);
    });
});


function humanize(categoryId){

  switch(categoryId){
    case 'aspnet': return 'ASP.NET';
    case 'aws': return 'AWS';
    case 'clickonce': return 'ClickOnce';
    case 'edgecast': return 'EdgeCast';
    case 'elmah': return 'ELMAH';
    case 'entityframework': return 'Entity Framework';
    case 'event-tracing': return 'Event Tracing for Windows';
    case 'filesystem': return 'File System';
    case 'github': return 'GitHub';
    case 'ghostinspector': return 'Ghost Inspector';
    case 'hipchat': return 'HipChat';
    case 'hockeyapp': return 'HockeyApp';
    case 'http': return 'HTTP';
    case 'iis': return 'IIS';
    case 'linux': return 'Linux';
    case 'microsoft-teams': return 'Microsoft Teams';
    case 'netscaler': return 'NetScaler';
    case 'newrelic': return 'New Relic';
    case 'nunit': return 'NUnit';
    case 'pagerduty': return 'PagerDuty';
    case 'ravendb': return 'RavenDB';
    case 'rabbitmq': return 'RabbitMQ';
    case 'readyroll': return 'ReadyRoll';
    case 'sharepoint': return 'SharePoint';
    case 'solarwinds': return 'SolarWinds';
    case 'sql': return 'SQL Server';
    case 'ssl': return 'SSL';
    case 'statuspage': return 'StatusPage';
    case 'teamcity': return 'TeamCity';
    case 'webdeploy': return 'Web Deploy';
    case 'xml': return 'XML';
    default: return categoryId[0].toUpperCase() + categoryId.substr(1).toLowerCase();
  }
}

function provideMissingData() {

  return eventStream.map(function(file, cb) {

      var fileContent = file.contents.toString();
      var template = JSON.parse(fileContent);
      var pathParts = file.path.split('\\');
      var fileName = pathParts[pathParts.length - 1];

      if (!template.HistoryUrl) {
        template.HistoryUrl = 'https://github.com/OctopusDeploy/Library/commits/master/step-templates/' + fileName;
      }

      if (!template.Website) {
        template.Website = '/step-templates/' + template.Id;
      }

      var categoryId = template.Category;
      if (!categoryId) {
        categoryId = 'other';
      }

      categoryId = categoryId.toLowerCase();

      template.Category = humanize(categoryId);

      if (!template.Logo) {
        var logo = fs.readFileSync('./step-templates/logos/' + categoryId + '.png');
        template.Logo = new Buffer(logo).toString('base64');
      }

      file.contents = new Buffer(JSON.stringify(template));

      cb(null, file);
  });
}


gulp.task('step-templates', ['tests'], () => {
  return gulp.src('./step-templates/*.json')
    .pipe(provideMissingData())
    .pipe(concat('step-templates.json', {newLine: ','}))
    .pipe(header('{"items": ['))
    .pipe(footer(']}'))
    .pipe(argv.production ? gulp.dest(`${publishDir}/app/services`) : gulp.dest(`${buildDir}/app/services`));
});

gulp.task('styles:vendor', () => {
  return gulp.src(vendorStyles, {base: 'node_modules/'})
    .pipe(argv.production ? gulp.dest(`${publishDir}/public/styles/vendor`) : gulp.dest(`${buildDir}/public/styles/vendor`));
});

gulp.task('styles:client', () => {
  return gulp.src(`${clientDir}/content/styles/main.scss`)
    .pipe(sass().on('error', sass.logError))
    .pipe($.if(argv.production, sourcemaps.init({loadMaps: true})))
    .pipe($.if(argv.production, cssnano())).on('error', gutil.log)
    .pipe($.if(argv.production, rename({suffix: '.min'})))
    .pipe($.if(argv.production, rev()))
    .pipe($.if(argv.production, sourcemaps.write('.')))
    .pipe(argv.production ? gulp.dest(`${publishDir}/public/styles`) : gulp.dest(`${buildDir}/public/styles`));
});

gulp.task('images', () => {
  return gulp.src(`${clientDir}/content/images/**/*{.png,.gif,.jpeg,.jpg,.bmp}`)
    .pipe(argv.production ? gulp.dest(`${publishDir}/public/images`) : gulp.dest(`${buildDir}/public/images`));
});

gulp.task('copy:app', () => {
  return gulp.src(`${clientDir}/**/*{.jsx,.js}`)
    .pipe(argv.production ? gulp.dest(`${publishDir}/app`) : gulp.dest(`${buildDir}/app`));
});

gulp.task('copy:configs', () => {
  return gulp.src(['./package.json', './web.config', './IISNode.yml'])
    .pipe(argv.production ? gulp.dest(`${publishDir}`) : gulp.dest(`${buildDir}`));
});

gulp.task('scripts', ['lint:client'], () => {
  return browserify({
    entries: `./${clientDir}/Browser.jsx`,
    extensions: ['.jsx', '.js'],
    debug: true
  })
    .transform(babelify)
    .transform(reactify)
    .transform(envify({'_': 'purge', 'NODE_ENV': argv.production ? 'production' : 'development'}), {global: true})
    .bundle()
    .pipe(source('app.js'))
    .pipe(buffer())
    .pipe($.if(argv.production, sourcemaps.init({loadMaps: true})))
    .pipe($.if(argv.production, uglify())).on('error', gutil.log)
    .pipe($.if(argv.production, rename({suffix: '.min'})))
    .pipe($.if(argv.production, rev()))
    .pipe($.if(argv.production, sourcemaps.write('.')))
    .pipe(argv.production ? gulp.dest(`${publishDir}/public/scripts`) : gulp.dest(`${buildDir}/public/scripts`));
});

gulp.task('build:client', ['step-templates', 'copy:app', 'scripts', 'styles:client', 'styles:vendor', 'images'], () => {
  let vendorSources = gulp.src(vendorStyles, {base: 'node_modules/'});

let sources = argv.production
  ? gulp.src([`${publishDir}/public/**/*.js`, `${publishDir}/public/**/*.css*`, `!${publishDir}/public/**/vendor{,/**}`], {read: false})
  : gulp.src([`${buildDir}/public/**/*.js`, `${buildDir}/public/**/*.css*`, `!${buildDir}/public/**/vendor{,/**}`], {read: false});

return gulp.src(`${serverDir}/views/index.jade`)
  .pipe(inject(vendorSources, {relative: false, name: 'vendor', ignorePath: 'node_modules', addPrefix: 'styles/vendor'}))
  .pipe(inject(sources, {relative: false, ignorePath: `${argv.production ? `${publishDir}` : `${buildDir}`}/public`}))
  .pipe(argv.production ? gulp.dest(`${publishDir}/views`) : gulp.dest(`${buildDir}/views`));
});

gulp.task('build:server', ['lint:server'], () => {
  return gulp.src([`./${serverDir}/server.js`])
    .pipe($.babel())
    .pipe(argv.production ? gulp.dest(`${publishDir}`) : gulp.dest(`${buildDir}`));
});

gulp.task('build', ['build:server', 'build:client', 'copy:configs']);

gulp.task('watch', ['clean', 'build'], () => {
  let server = LiveServer(`${buildDir}/server.js`);
server.start();

browserSync.init(null, {
  proxy: 'http://localhost:9000'
});

gulp.watch(`${clientDir}/**/*.jade`, ['build:client']);
gulp.watch(`${clientDir}/**/*.jsx`, ['scripts', 'copy:app']);
gulp.watch(`${clientDir}/content/styles/**/*.scss`, ['styles:client']);
gulp.watch('step-templates/*.json', ['step-templates']);

gulp.watch(`${buildDir}/**/*.*`).on('change', reload);
});

gulp.task('default', ['clean', 'build']);
