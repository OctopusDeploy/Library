var module = angular.module('octopus-library');

module.filter('toJson', function(){
  return function(val) {
    return JSON.stringify(val, null, 2);
  };
});
