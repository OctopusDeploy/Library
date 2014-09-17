var module = angular.module('octopus-library');

module.config(function($routeProvider, $locationProvider) {
  $routeProvider.otherwise({
    redirectTo: '/listing'
  });

  $locationProvider
    .html5Mode(false)
    .hashPrefix('!');
});

module.run(function($window){
  if ($window.location.href.indexOf('/#/') !== -1) {
    $window.location = $window.location.href.replace('/#/', '/#!/');
  }
});
