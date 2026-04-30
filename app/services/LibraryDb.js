"use strict";

import fs from "fs";
import path from "path";
import _ from "underscore";

class LibraryDb {
  constructor() {
    this._items = null;
    this._all = null;
  }

  isDevelopment() {
    return process.env.NODE_ENV === "development";
  }

  readTemplatesFromDisk() {
    const templatePath = path.join(__dirname, "step-templates.json");
    return JSON.parse(fs.readFileSync(templatePath, "utf8"));
  }

  hydrateTemplates(stepTemplates) {
    const items = _.chain(stepTemplates.items)
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

    return {
      items,
      all: _.indexBy(items, "Id"),
    };
  }

  loadTemplates() {
    return this.hydrateTemplates(this.readTemplatesFromDisk());
  }

  getTemplates() {
    if (this.isDevelopment()) {
      return this.loadTemplates();
    }

    if (!this._items || !this._all) {
      const templates = this.loadTemplates();
      this._items = templates.items;
      this._all = templates.all;
    }

    return {
      items: this._items,
      all: this._all,
    };
  }

  list(cb) {
    cb(null, this.getTemplates().items);
  }

  get(id, cb) {
    var item = this.getTemplates().all[id];
    cb(null, item);
  }
}

export default new LibraryDb();
