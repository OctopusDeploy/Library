var module = angular.module('octopus-library', [
  'ngRoute'
]);

module.config(function($routeProvider) {
  $routeProvider.otherwise({
    redirectTo: '/listing'
  });
});
