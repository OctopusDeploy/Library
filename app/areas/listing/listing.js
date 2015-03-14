var module = angular.module('octopus-library');

module.config(function($routeProvider){
  $routeProvider.when('/listing/:searchTerm?', {
    templateUrl: 'areas/listing/listing_index.tpl.html',
    controller: 'ListingIndexController'
  });
});
