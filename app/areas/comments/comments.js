var module = angular.module('octopus-library');

module.directive('comments', function($location, $window, $timeout, $document){
  return {
    restrict: 'E',
    replace: true,
    templateUrl: 'areas/comments/comments.tpl.html',
    scope: {
      thread: '@'
    },
    link: function(scope) {
      var reset = function(){
        $timeout(function() {
          var dummy = $document[0].getElementById('dummy_disqus_thread');
          if (dummy) {
            dummy.parentNode.removeChild(dummy);
          }

          $window.DISQUS.reset({
            reload: true,
            config: function () {
              this.page.identifier = scope.thread;
              this.page.url = $location.absUrl().replace('#', '#!');
            }
          });
        }, 1000);
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
