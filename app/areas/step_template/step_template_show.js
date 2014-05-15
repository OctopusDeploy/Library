var module = angular.module('octopus-library');

module.controller('StepTemplateShowController', function($scope, $routeParams, library, analytics){
  var id = $routeParams.id;

  $scope.stepTemplate = library.get(id);

  $scope.onCopied = function() {
    $scope.copied = true;
    analytics.sendEvent('template', 'copied', id);
  };
});
