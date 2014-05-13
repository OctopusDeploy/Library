var module = angular.module('octopus-library');

module.directive('navigation', function(){
  return {
    restrict: 'E',
    replace: true,
    templateUrl: 'areas/navigation/navigation.tpl.html'
  };
});
