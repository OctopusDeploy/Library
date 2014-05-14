var module = angular.module('octopus-library');

module.config(function(){
  // Based on https://github.com/isagalaev/highlight.js/blob/master/src/languages/bash.js
  var hljs = window.hljs;

  hljs.registerLanguage('powershell', function (hljs) {
    var VAR = {
      className: 'variable',
      variants: [
        {begin: /\$[\w\d][\w\d_:]*/}
      ]
    };
    var QUOTE_STRING = {
      className: 'string',
      begin: /"/, end: /"/,
      contains: [
        hljs.BACKSLASH_ESCAPE,
        VAR,
        {
          className: 'variable',
          begin: /\$/, end: /[^A-z]/,
          contains: [hljs.BACKSLASH_ESCAPE]
        }
      ]
    };
    var APOS_STRING = {
      className: 'string',
      begin: /'/, end: /'/
    };

    return {
      aliases: ['ps'],
      lexemes: /-?[A-z\.\-]+/,
      case_insensitive: true,
      keywords: {
        keyword: 'if else foreach return function',
        literal: '$null $true $false',
        built_in: 'new-object write-host write-output invoke-expression',
        operator: '-ne -eq -lt -gt -not -lte -gte'
      },
      contains: [
        hljs.HASH_COMMENT_MODE,
        hljs.NUMBER_MODE,
        QUOTE_STRING,
        APOS_STRING,
        VAR
      ]
    };
  });
});
