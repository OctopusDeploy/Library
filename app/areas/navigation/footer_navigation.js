var module = angular.module('octopus-library');

module.directive('footerNavigation', function(){
  return {
    restrict: 'E',
    replace: true,
    templateUrl: 'areas/navigation/footer_navigation.tpl.html'
  };
});

