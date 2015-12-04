var module = angular.module('octopus-library');

module.controller('StepTemplateShowController', function($scope, $routeParams, $location, library, analytics){
  var id = $routeParams.id;

  $scope.currentPage = $location.path();
  $scope.stepTemplate = library.get(id);

  $scope.onCopied = function() {
    $scope.copied = true;
    analytics.sendEvent('template', 'copied', id);
  };

  $scope.showModal = false;
  $scope.toggleModal = function() {
    $scope.showModal = !$scope.showModal;
  };  
});
