var module = angular.module('octopus-library');

module.directive('tracked', function(analytics){
  return {
    restrict: 'A',
    link: function($scope) {
      $scope.$on('$viewContentLoaded', function() {
        analytics.sendPageView();
      });
    }
  };
});
