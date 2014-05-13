var module = angular.module('octopus-library');

module.directive('clickToCopy', function(){
  return {
    restrict: 'A',
    scope: {
      clickToCopy: '=',
      onCopied: '&'
    },
    link: function(scope, el) {
      el.attr('data-clipboard-text', (scope.clickToCopy || '').toString());

      var clip = new ZeroClipboard(el);

      clip.on('load', function(client) {
        client.on('complete', function() {
          el.addClass('copied');
          if (typeof scope.onCopied === 'function') {
            scope.$apply(function(){
              scope.onCopied();
            });
          }
        });
      });
    }
  };
});
