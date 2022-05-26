"use strict";

import { EventEmitter } from "events";
import _ from "underscore";
import SlugMaker from "./../services/SlugMaker";
import AppDispatcher from "./../dispatcher.js";

const CHANGE_EVENT = "change";

let _templates = [];
let _indexedTemplates = [];

function receiveTemplates(templates) {
  _templates = templates;
  _indexedTemplates = _.indexBy(_templates, "Id");
}

class LibraryStore extends EventEmitter {
  constructor() {
    super();
  }

  getItems() {
    return _templates;
  }

  get(id) {
    return _indexedTemplates[id];
  }

  emitChange() {
    this.emit(CHANGE_EVENT);
  }

  //Required so we can handle old urls without stable ids
  getByFriendlySlug(slug) {
    return this.getItems().filter((t) => SlugMaker.make(t.Name) === slug)[0];
  }

  addChangeListener(callback) {
    this.on(CHANGE_EVENT, callback);
  }

  removeChangeListener(callback) {
    this.removeListener(CHANGE_EVENT, callback);
  }
}

let storeObj = new LibraryStore();

storeObj.dispatchToken = AppDispatcher.register((action) => {
  switch (action.actionType) {
    case "READ_SUCCESS":
      receiveTemplates(action.templates);
      storeObj.emitChange();
      break;
    default:
  }
});

export default storeObj;
