var module = angular.module('octopus-library');

module.controller('ListingIndexController', function($scope, library){
  $scope.list = library.list();
});
