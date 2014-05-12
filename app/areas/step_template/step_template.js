var module = angular.module('octopus-library');

module.config(function($routeProvider){
  $routeProvider.when('/step-template/:id', {
    templateUrl: 'areas/step_template/step_template_show.tpl.html',
    controller: 'StepTemplateShowController'
  });
});
