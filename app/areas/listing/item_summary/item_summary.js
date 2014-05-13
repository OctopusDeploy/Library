var module = angular.module('octopus-library');

module.directive('itemSummary', function() {
  return {
    restrict: 'E',
    scope: {
      model: '='
    },
    templateUrl: 'areas/listing/item_summary/item_summary.tpl.html'
  };
});
