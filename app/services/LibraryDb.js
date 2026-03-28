"use strict";

import fs from "fs";
import path from "path";
import _ from "underscore";

class LibraryDb {
  loadTemplates() {
    const templatePath = path.join(__dirname, "step-templates.json");
    const stepTemplates = JSON.parse(fs.readFileSync(templatePath, "utf8"));

    return _.chain(stepTemplates.items)
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
  }

  list(cb) {
    cb(null, this.loadTemplates());
  }

  get(id, cb) {
    var item = _.indexBy(this.loadTemplates(), "Id")[id];
    cb(null, item);
  }
}

export default new LibraryDb();
