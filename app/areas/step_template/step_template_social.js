var module = angular.module('octopus-library');

module.directive('stepTemplateSocialLinks', function() {
  return {
    restrict: 'E',
    replace: true,
    scope: {
      stepTemplateUrl: '='
    },
    templateUrl: 'areas/step_template/step_template_social.tpl.html',
    link: function (scope, element) {

      (function () {
          var po = document.createElement('script');
          po.type = 'text/javascript';
          po.async = true;
          po.src = '//apis.google.com/js/plusone.js';
          var s = document.getElementsByTagName('script')[0];
          s.parentNode.insertBefore(po, s);
      }());

      (function (d, s, id) {
        var js, fjs = d.getElementsByTagName(s)[0];
        js = d.createElement(s);
        js.type = "text/javascript";
        js.async = true;
        js.src = "//platform.twitter.com/widgets.js";
        fjs.parentNode.insertBefore(js, fjs);
      }(document, "script", "twitter-wjs"));

      (function(d, s, id) {
        var js, fjs = d.getElementsByTagName(s)[0];
        js = d.createElement(s);
        js.type = "text/javascript";
        js.async = true;
        js.src = "//connect.facebook.net/en_US/sdk.js#xfbml=1&version=v2.5";
        fjs.parentNode.insertBefore(js, fjs);
      }(document, "script", "facebook-jssdk"));

    }
  };
});
