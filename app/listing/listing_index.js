var module = angular.module('octopus-library');

module.controller('ListingIndexController', function($scope, stepTemplates){
  $scope.stepTemplates = stepTemplates;
});
