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

gulp.task('step-templates', ['clean'], function() {
  return gulp.src(['step-templates/*.json'])
    .pipe(concat('4-step-templates.js', {newLine: ','}))
    .pipe(header('angular.module("octopus-library").factory("stepTemplates", function() { return ['))
    .pipe(footer(']; });'))
    .pipe(jshint())
    .pipe(uglify())
    .pipe(gulp.dest('build'));
});

gulp.task('scripts-app', ['clean'], function() {
  return gulp.src(['app/**/*_module.js', 'app/**/*.js'])
    .pipe(jshint())
    .pipe(concat('2-app.js'))
    .pipe(uglify({mangle: false}))
    .pipe(gulp.dest('build'));
});

gulp.task('scripts-vendor', ['clean'], function() {
  return gulp.src([
      'bower_components/angular/angular.min.js',
      'bower_components/angular-route/angular-route.min.js'
    ])
    .pipe(concat('1-vendor.js'))
    .pipe(gulp.dest('build'));
});

gulp.task('views', ['clean'], function(){
  return gulp.src('app/**/*.tpl.html')
    .pipe(ngHtml2Js({
      moduleName: 'octopus-library',
      rename: function (url) {
        return url.replace('.tpl.html', '.html');
      }
    }))
    .pipe(concat("3-views.js"))
    .pipe(uglify())
    .pipe(gulp.dest('build'));
});

gulp.task('scripts', ['scripts-app', 'scripts-vendor', 'views', 'step-templates'], function() {
});

gulp.task('styles', ['clean'], function() {
  return gulp.src(['app/**/*.css'])
    .pipe(concat('app.css'))
    .pipe(minifyCss())
    .pipe(gulp.dest('build'));
});

gulp.task('rev', ['scripts', 'styles'], function() {
  return gulp.src(['build/**/*.css', 'build/**/*.js'])
    .pipe(rev())
    .pipe(gulp.dest('dist'))
    .pipe(rev.manifest())
    .pipe(gulp.dest('build'));
});

gulp.task('html-release', ['rev'], function() {
  return gulp.src('dist/**/*.*')
    .pipe(inject('app/app.html', {
      addRootSlash: false,
      ignorePath: '/dist/'
    }))
    .pipe(rename('index.html'))
    .pipe(gulp.dest('dist'));
});

gulp.task('html-debug', ['rev'], function() {
  return gulp.src('build/**/*.*')
    .pipe(inject('app/app.html', {
      addRootSlash: false,
      ignorePath: '/build/'
    }))
    .pipe(rename('index.html'))
    .pipe(gulp.dest('build'));
});

gulp.task('clean', function() {
  return gulp.src(['build', 'dist'], {read: false})
    .pipe(clean());
});

gulp.task('build', ['html-debug', 'html-release'], function() {
});

gulp.task('default', ['build'], function() {
});

gulp.task('watch', ['build'],  function(){
  gulp.watch(['app/**/*'], ['build']);
});
