var module = angular.module('octopus-library');

module.directive('searchBox', function() {
  return {
    restrict: 'E',
    replace: true,
    templateUrl: 'listing/search_box/search_box.tpl.html',
    scope: {
      criteria: '='
    }
  };
});
