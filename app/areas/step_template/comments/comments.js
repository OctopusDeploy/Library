var module = angular.module('octopus-library');

module.directive('comments', function($location, $window, $timeout){
  return {
    restrict: 'E',
    replace: true,
    templateUrl: 'areas/step_template/comments/comments.tpl.html',
    scope: {
      thread: '@'
    },
    link: function(scope) {
      var reset = function(){
        $window.DISQUS.reset({
          reload: true,
          config: function () {
            this.page.identifier = scope.thread;
            this.page.url = $location.absUrl().replace('#', '#!');
          }
        });
      };
      if (typeof $window.DISQUS === 'object') {
        reset();
      } else {
        var attempt = function() {
          if (typeof $window.DISQUS === 'object') {
            reset();
          } else {
            $timeout(attempt, 500);
          }
        };
        $timeout(attempt, 500);
      }
    }
  };
});
