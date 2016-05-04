'use strict';

import _ from 'underscore';

import StepTemplates from './step-templates.json';

function makeSlug(name) {
  return name.replace(/ \- /g, '-').replace(/ /g, '-').toLowerCase();
}

function makeId(type, name) {
  let slug = makeSlug(name);
  return type.toLowerCase() + '-' + slug;
}

function makeScriptClass(actionType) {
  return actionType.replace(/\./g, '-').toLowerCase();
}

class LibraryDb {
  constructor() {
    this._items = _.chain(StepTemplates.items)
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
        return t.Body.Name.toLowerCase();
      })
      .value();

    this._all = _.indexBy(this._items, 'Id');
  }

  list(cb) {
    cb(null, this._items);
  }

  get(id, cb) {
    var item = this._all[id];
    cb(null, item.Body);
  }
}

export default new LibraryDb();
