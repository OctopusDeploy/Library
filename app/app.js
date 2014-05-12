var module = angular.module('octopus-library');

module.config(function($routeProvider) {
  $routeProvider.otherwise({
    redirectTo: '/listing'
  });
});
