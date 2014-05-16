module.exports = function(grunt) {
  grunt.loadNpmTasks('grunt-html-snapshot');

  grunt.initConfig({
    htmlSnapshot: {
      all: {
        options: {
          snapshotPath: 'tmp/generated/',
          sitePath: 'http://localhost:4000',
          urls: [
            '#!/listing',
            '#!/step-template/actiontemplate-windows-scheduled-task-disable']
        }
      }
    }
  });

  grunt.registerTask('default', ['htmlSnapshot']);
};
