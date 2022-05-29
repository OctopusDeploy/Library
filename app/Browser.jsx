"use strict";

import React from "react";
import ReactDOM from "react-dom";
import { match, Router, browserHistory } from "react-router";

import Analytics from "./services/Analytics.js";

import LibraryActions from "./actions/LibraryActions";
import routes from "./Routes";

function onRouteChange() {
  Analytics.sendPageView();
}

LibraryActions.sendTemplates(window.stepTemplates, () => {
  ReactDOM.render(
    <Router history={browserHistory} onUpdate={onRouteChange}>
      {routes}
    </Router>,
    document.getElementById("reactRoot")
  );
});
