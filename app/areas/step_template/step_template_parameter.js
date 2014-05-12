var module = angular.module('octopus-library');

module.directive('stepTemplateParameter', function(){
  return {
    restrict: 'E',
    replace: true,
    scope: {
      model: '='
    },
    templateUrl: 'areas/step_template/step_template_parameter.tpl.html'
  };
});
