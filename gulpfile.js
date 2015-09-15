var gulp = require('gulp');

var uglify = require('gulp-uglify');
var concat = require('gulp-concat');
var rev = require('gulp-rev');
var minifyCss = require('gulp-minify-css');
var inject = require('gulp-inject');
var clean = require('gulp-clean');
var jshint = require('gulp-jshint');
var rename = require('gulp-rename');
var ngHtml2Js = require("gulp-ng-html2js");
var header = require("gulp-header");
var footer = require("gulp-footer");
var replace = require('gulp-replace');
var sourceUrl = require('gulp-source-url');
var filter = require('gulp-filter');
var childProcess = require('child_process');
var data = require('gulp-data');

var reExt = function(ext) {
  return rename(function(path) { path.extname = ext; })
};

gulp.task('prepare-snapshot', ['clean'], function(){
  return gulp.src(['snapshot-sitemap.tpl.json'])
    .pipe(inject(gulp.src(['step-templates/*.json'], {read: false}), {
      starttag: '"urls": ["#!/listing"',
      endtag: ']',
      transform: function (filepath, file, i, length) {
        return ',"#!/step-template/actiontemplate-' + filepath.replace('/step-templates/', '').replace('.json', '') + '"';
      }
    }))
    .pipe(rename('snapshot-sitemap.json'))
    .pipe(gulp.dest('tmp/html-snapshot'));
});

gulp.task('step-templates', ['clean'], function() {
  return gulp.src(['step-templates/*.json'])
    .pipe(jshint())
    .pipe(jshint.reporter('default'))
    .pipe(jshint.reporter('fail'))
    .pipe(replace('\r', ' '))
    .pipe(replace('\n', ' '))
    .pipe(concat('4-step-templates.js', {newLine: ','}))
    .pipe(header('angular.module("octopus-library").factory("stepTemplates", function() { return ['))
    .pipe(footer(']; });'))
    .pipe(gulp.dest('build/public'))
    .pipe(uglify())
    .pipe(reExt('.min.js'))
    .pipe(gulp.dest('build/public'));
});

gulp.task('scripts-app', ['clean'], function() {
  return gulp.src(['app/**/*_module.js', 'app/**/*.js'])
    .pipe(jshint())
    .pipe(jshint.reporter('default'))
    .pipe(jshint.reporter('fail'))
    .pipe(sourceUrl())
    .pipe(concat('2-app.js'))
    .pipe(gulp.dest('build/public'))
    .pipe(uglify({mangle: false}))
    .pipe(reExt('.min.js'))
    .pipe(gulp.dest('build/public'));
});

gulp.task('scripts-vendor', ['clean'], function() {
  var notMinJS = filter('!*.min.js');
  var minJS = filter('*.min.js');

  return gulp.src([
      'bower_components/angular/angular.min.js',
      'bower_components/angular-route/angular-route.min.js',
      'bower_components/underscore/underscore.js',
      'bower_components/showdown/src/showdown.js',
      'bower_components/zeroclipboard/zeroclipboard.min.js',
      'vendor/highlight.js/highlight.js',
      'bower_components/rem-unit-polyfill/src/rem.min.js',
      'bower_components/moment/moment.js'
    ])
    .pipe(notMinJS)
    .pipe(uglify())
    .pipe(reExt('.min.js'))
    .pipe(notMinJS.restore())
    .pipe(minJS)
    .pipe(concat('1-vendor.js'))
    .pipe(gulp.dest('build/public'))
    .pipe(reExt('.min.js'))
    .pipe(gulp.dest('build/public'));
});

gulp.task('views', ['clean'], function(){
  return gulp.src('app/**/*.tpl.html')
    .pipe(ngHtml2Js({moduleName: 'octopus-library'}))
    .pipe(concat("3-views.js"))
    .pipe(gulp.dest('build/public'))
    .pipe(uglify())
    .pipe(reExt('.min.js'))
    .pipe(gulp.dest('build/public'));
});

gulp.task('scripts', ['scripts-app', 'scripts-vendor', 'views', 'step-templates']);

gulp.task('styles', ['clean'], function() {
  return gulp.src([
      'bower_components/normalize.css/normalize.css',
      'vendor/highlight.js/styles/github.css',
      'app/**/*.css'
    ])
    .pipe(concat('app.css'))
    .pipe(minifyCss())
    .pipe(gulp.dest('build/public'));
});

gulp.task('flash', ['clean'], function(){
  return gulp.src([
      // Ideally this wouldn't go into the root dir, but having trouble
      // configuring the library to do otherwise.
      'bower_components/zeroclipboard/zeroclipboard.swf'
    ])
    .pipe(gulp.dest('build/public'))
    .pipe(gulp.dest('dist/public'));
});

gulp.task('images', ['clean'], function(){
    return gulp.src([
      'app/img/*'
    ])
    .pipe(gulp.dest('build/public/img'))
    .pipe(gulp.dest('dist/public/img'));
});

gulp.task('assets', ['images', 'flash']);

gulp.task('rev', ['scripts', 'styles'], function() {
  return gulp.src(['build/public/**/*.css', 'build/public/**/*.min.js'])
    .pipe(rev())
    .pipe(gulp.dest('dist/public'))
    .pipe(rev.manifest())
    .pipe(gulp.dest('build/public'));
});

gulp.task('html-release', ['rev', 'assets'], function() {
  return gulp.src('dist/public/**/*.*')
    .pipe(inject('app/app.html', {
      addRootSlash: false,
      ignorePath: '/dist/public/'
    }))
    .pipe(rename('index.html'))
    .pipe(gulp.dest('dist/public'));
});

gulp.task('html-debug', ['rev', 'assets'], function() {
  var notMinJS = filter('!*.min.js');

  return gulp.src('build/public/**/*.*')
    .pipe(notMinJS)
    .pipe(inject('app/app.html', {
      addRootSlash: false,
      ignorePath: '/build/public/'
    }))
    .pipe(rename('index.html'))
    .pipe(gulp.dest('build/public'));
});

gulp.task('clean', function() {
  return gulp.src(['build', 'dist', 'tmp'], {read: false})
    .pipe(clean());
});

gulp.task('server', ['clean'], function(){
  return gulp.src(['package.json', 'server/server.js', 'server/express_app.js'])
    .pipe(jshint())
    .pipe(jshint.reporter('default'))
    .pipe(jshint.reporter('fail'))
    .pipe(gulp.dest('build'))
    .pipe(gulp.dest('dist'));
});

gulp.task('baseline', ['html-debug', 'html-release', 'server']);

var start = function() {
  process.env.OCTO_PUBLIC = 'build/public';

  var expressApp = require('./build/express_app.js');
  return expressApp();
};

gulp.task('snapshot', ['baseline', 'prepare-snapshot'], function(cb) {
  var server = start();

  childProcess.exec('grunt', function(error, stdout, stderr){
    console.log(stdout);
    console.log(stderr);

    if (error) {
      console.log(error);
    }

    server.close();

    cb(error);
  });
});

gulp.task('install-snapshot', ['snapshot'], function() {
  return gulp.src(['tmp/generated/*.html'])
    .pipe(reExt('.gen.html'))
    .pipe(rename(function(path){
      path.basename = path.basename.replace('snapshot____', '');
    }))
    .pipe(gulp.dest('build/public/generated'))
    .pipe(gulp.dest('dist/public/generated'));
});

gulp.task('expand-step-templates' , function() {
  return gulp.src(['step-templates/*.json'])
    .pipe(data(function(file) {
      var content = String(file.contents);
      try{
        var json = JSON.parse(content);
      } catch(ex){
        console.log("warning failed to parse \n" + content);
        return new Buffer(file.contents).attributes;
      }
      var fileContents = json.Properties["Octopus.Action.Script.ScriptBody"] ? json.Properties["Octopus.Action.Script.ScriptBody"] : ""
      file.contents = new Buffer(fileContents);

      return content.attributes;
    }))
    .pipe(rename({
      dirname: "step-templates",
      extname: ".ps1"
    }))
    .pipe(gulp.dest('tmp'));
});

gulp.task('build', ['install-snapshot']);

gulp.task('default', ['build']);

gulp.task('start', [], function(cb){
  start();
});

gulp.task('watch', ['build'],  function(cb){
  start();
  gulp.watch(['app/**/*'], ['html-debug']);
});
