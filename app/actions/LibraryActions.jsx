"use strict";

import AppDispatcher from "./../dispatcher.js";

const LibraryActions = {
  sendTemplates(templates, callback) {
    AppDispatcher.dispatch({
      actionType: "READ_SUCCESS",
      templates: templates,
    });
    callback();
  },
};

export default LibraryActions;
