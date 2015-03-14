var module = angular.module('octopus-library');

module.controller('ListingIndexController', function($scope, $routeParams, library, searchCriteria){
  var searchTerm = $routeParams.searchTerm;
  $scope.list = library.list();
  $scope.searchCriteria = searchCriteria.create($scope.list.length, searchTerm);
});
