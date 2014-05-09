var module = angular.module('octopus-library');

// highlight.js doesn't play nicely if the
// <pre> isn't in the DOM to start with...
module.directive('highlight', function($timeout){
  return {
    restrict: 'A',
    replace: false,
    transclude: true,
    template: '<code ng-transclude></code>',
    link: function(scope, el, attr) {
      el.addClass(attr.highlight);
      $timeout(function() { window.hljs.highlightBlock(el[0]); });
    }
  };
});

