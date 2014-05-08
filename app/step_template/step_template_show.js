var module = angular.module('octopus-library');

module.controller('StepTemplateShowController', function($scope, $routeParams, stepTemplates){
  var name = $routeParams.name;

  $scope.stepTemplate = _.find(stepTemplates, function(t){ return t.Name === name; });
});

