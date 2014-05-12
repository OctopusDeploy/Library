var module = angular.module('octopus-library');

module.config(function($routeProvider){
  $routeProvider.when('/listing', {
    templateUrl: 'areas/listing/listing_index.tpl.html',
    controller: 'ListingIndexController'
  });
});
