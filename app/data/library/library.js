var module = angular.module('octopus-library');

module.factory('library', function(stepTemplates) {
  var makeId = function(type, name) {
    var spinal = name.replace(/ \- /g, '-').replace(/ /g, '-');
    return (type + '-' + spinal).toLowerCase();
  };

  var items = _.chain(stepTemplates)
    .map(function(t) {
      return {
        Id: makeId(t.$Meta.Type, t.Name),
        Name: t.Name,
        Description: t.Description,
        OctopusVersion: t.$Meta.OctopusVersion,
        ExportedAt: t.$Meta.ExportedAt,
        Type: t.$Meta.Type,
        Author: t.LastModifiedBy,
        Body: t
      };
    })
    .sortBy(function(t) {
      return t.Body.Name;
    })
    .value();

  var all = _.indexBy(items, 'Id');

  return {
    list: function() { return items; },
    get: function(id) { return all[id]; }
  };
});
