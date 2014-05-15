var module = angular.module('octopus-library');

module.directive('comments', function($location){
  return {
    restrict: 'E',
    replace: true,
    templateUrl: 'areas/step_template/comments/comments.tpl.html',
    scope: {
      thread: '@'
    },
    link: function() {
      if (typeof DISQUS === 'object') {
        DISQUS.reset({
          reload: true,
          config: function () {
            this.page.identifier = scope.thread;
            this.page.url = $location.absUrl();
          }
        });
      }
    }
  };
});
