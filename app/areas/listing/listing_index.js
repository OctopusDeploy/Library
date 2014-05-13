var module = angular.module('octopus-library');

module.controller('ListingIndexController', function($scope, library, searchCriteria){
  $scope.list = library.list();
  $scope.searchCriteria = searchCriteria.create($scope.list.length);
});
