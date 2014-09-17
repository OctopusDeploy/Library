var module = angular.module('octopus-library');

module.config(function(){
  // Based on https://github.com/isagalaev/highlight.js/blob/master/src/languages/bash.js
  var hljs = window.hljs;

  hljs.registerLanguage('powershell', function (hljs) {
    var backtickEscape = {
      begin: '`[\\s\\S]',
      relevance: 0
    };
    var dollarEscape = {
      begin: '\\$\\$[\\s\\S]',
      relevance: 0
    };
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
        backtickEscape,
        VAR,
        {
          className: 'variable',
          begin: /\$[A-z]/, end: /[^A-z]/
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
        keyword: 'if else foreach return function do while until',
        literal: '$null $true $false',
        built_in: 'new-object write-host write-output invoke-expression test-path write-warning write-error select-object where-object',
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
