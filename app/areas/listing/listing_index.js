var module = angular.module('octopus-library');

module.controller('ListingIndexController', function($scope, library, searchCriteria){
  $scope.searchCriteria = searchCriteria.create();
  $scope.list = library.list();
});
