"use strict";

import uuid from "node-uuid";

let _callbacks = {};

const AppDispatcher = {
  register(callback) {
    var id = uuid.v4();
    _callbacks[id] = callback;
    return id;
  },

  dispatch(payload) {
    for (var id in _callbacks) {
      var callback = _callbacks[id];
      callback(payload);
    }
  },
};

export default AppDispatcher;
