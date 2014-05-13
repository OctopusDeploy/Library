var module = angular.module('octopus-library');

module.filter('moment', function(){
  return function(val, arg) {
    if (!val) {
      return null;
    }

    var m = moment(val);

    if (arg === 'cal') {
      return m.calendar();
    }

    if (arg === 'ago') {
      return m.fromNow();
    }

    return m.format();
  };
});
