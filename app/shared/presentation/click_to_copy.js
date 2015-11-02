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

      var client = new ZeroClipboard(el);

      client.on('ready', function(readyEvent) {
        client.on('aftercopy', function(event) {
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
