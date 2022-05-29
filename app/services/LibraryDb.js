"use strict";

import _ from "underscore";

import StepTemplates from "./step-templates.json";

class LibraryDb {
  constructor() {
    this._items = _.chain(StepTemplates.items)
      .map(function (t) {
        if (t.Properties) {
          var script = t.Properties["Octopus.Action.Script.ScriptBody"];
          if (script) {
            t.Properties["Octopus.Action.Script.ScriptBody"] = script.replace(/(\r\n)/gm, "\n");
          }
        }

        return {
          Id: t.Id,
          Name: t.Name,
          Description: t.Description,
          Version: t.Version,
          ExportedAt: t.$Meta.ExportedAt,
          ActionType: t.ActionType,
          Author: t.LastModifiedBy,
          Packages: t.Packages,
          Parameters: t.Parameters,
          Properties: t.Properties,
          Category: t.Category,
          HistoryUrl: t.HistoryUrl,
          Website: t.Website,
          Logo: t.Logo,
          MaximumServerVersion: t.MaximumServerVersion,
          MinimumServerVersion: t.MinimumServerVersion,
          $Meta: {
            Type: "ActionTemplate",
          },
        };
      })
      .sortBy(function (t) {
        return t.Name.toLowerCase();
      })
      .value();

    this._all = _.indexBy(this._items, "Id");
  }

  list(cb) {
    cb(null, this._items);
  }

  get(id, cb) {
    var item = this._all[id];
    cb(null, item);
  }
}

export default new LibraryDb();
