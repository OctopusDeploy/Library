var module = angular.module('octopus-library');

module.controller('StepTemplateShowController', function($scope, $routeParams, library){
  var id = $routeParams.id;

  $scope.stepTemplate = library.get(id);
});

