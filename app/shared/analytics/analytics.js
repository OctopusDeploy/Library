var module = angular.module('octopus-library');

module.factory('analytics', function($location, $window) {
  var result = {};

  result.sendPageView = function() {
    $window.ga('send', 'pageview', $location.path());
  };

  result.sendEvent = function(cat, name, value) {
    $window.ga('send', 'event', cat, name, value);
  };

  return result;
});
