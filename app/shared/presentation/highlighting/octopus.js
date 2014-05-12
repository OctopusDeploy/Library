var module = angular.module('octopus-library');

module.config(function(){
  var hljs = window.hljs;

  hljs.registerLanguage('octopus', function (hljs) {
    var VAR = {
      className: 'variable',
      variants: [
        {begin: /#\{[\w_][\w_\.]*\}/}
      ]
    };
    return {
      contains: [
        VAR
      ]
    };
  });
});
