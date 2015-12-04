var module = angular.module('octopus-library');

module.factory('library', function(stepTemplates) {
  var makeSlug = function(name) {
    return name.replace(/ \- /g, '-').replace(/ /g, '-').toLowerCase();
  };

  var makeId = function(type, name) {
    var slug = makeSlug(name);
    return type.toLowerCase() + '-' + slug;
  };

  var makeScriptClass = function(actionType) {
    return actionType.replace(/\./g, '-').toLowerCase();
  };

  var items = _.chain(stepTemplates)
    .map(function(t) {
      if (t.Properties) {
        var script = t.Properties['Octopus.Action.Script.ScriptBody'];
        if (script) {
          t.Properties['Octopus.Action.Script.ScriptBody'] = script.replace(/(\r\n)/gm, '\n');
        }
      }
      return {
        Id: makeId(t.$Meta.Type, t.Name),
        Slug: makeSlug(t.Name),
        Name: t.Name,
        Description: t.Description,
        OctopusVersion: t.$Meta.OctopusVersion,
        ExportedAt: t.$Meta.ExportedAt,
        Type: t.$Meta.Type,
        Author: t.LastModifiedBy,
        ScriptClass: makeScriptClass(t.ActionType),
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
