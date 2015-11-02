var module = angular.module('octopus-library');

module.directive('markdown', function () {
  var converter = new showdown.Converter();
  return {
    restrict: 'E',
    scope: {
      text: '='
    },
    link: function (scope, element) {

      var refresh = function () {
        if (scope.text) {
          var html = converter.makeHtml(scope.text);
          element.html(html);
        } else {
          element.html('');
        }
      };
      scope.$watch('text', function () {
        refresh();
      });

      refresh();
    }
  };
});
