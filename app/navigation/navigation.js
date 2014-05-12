var module = angular.module('octopus-library');

module.directive('navigation', function(){
  return {
    restrict: 'E',
    replace: true,
    templateUrl: 'navigation/navigation.tpl.html'
  };
});
