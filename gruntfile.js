module.exports = function(grunt) {
  grunt.loadNpmTasks('grunt-html-snapshot');

  grunt.initConfig({
    htmlSnapshot: {
      all: {
        options: grunt.file.readJSON('tmp/html-snapshot/snapshot-sitemap.json')
      }
    }
  });

  grunt.registerTask('default', ['htmlSnapshot']);
};
