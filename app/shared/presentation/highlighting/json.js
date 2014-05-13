var module = angular.module('octopus-library');

module.config(function(){
  var hljs = window.hljs;

  // From https://github.com/isagalaev/highlight.js/blob/master/src/languages/json.js
  hljs.registerLanguage('json', function(hljs) {
    var LITERALS = {literal: 'true false null'};
    var TYPES = [
      hljs.QUOTE_STRING_MODE,
      hljs.C_NUMBER_MODE
    ];
    var VALUE_CONTAINER = {
      className: 'value',
      end: ',', endsWithParent: true, excludeEnd: true,
      contains: TYPES,
      keywords: LITERALS
    };
    var OBJECT = {
      begin: '{', end: '}',
      contains: [
        {
          className: 'attribute',
          begin: '\\s*"', end: '"\\s*:\\s*', excludeBegin: true, excludeEnd: true,
          contains: [hljs.BACKSLASH_ESCAPE],
          illegal: '\\n',
          starts: VALUE_CONTAINER
        }
      ],
      illegal: '\\S'
    };
    var ARRAY = {
      begin: '\\[', end: '\\]',
      contains: [hljs.inherit(VALUE_CONTAINER, {className: null})], // inherit is also a workaround for a bug that makes shared modes with endsWithParent compile only the ending of one of the parents
      illegal: '\\S'
    };
    TYPES.splice(TYPES.length, 0, OBJECT, ARRAY);
    return {
      contains: TYPES,
      keywords: LITERALS,
      illegal: '\\S'
    };
  });
});
