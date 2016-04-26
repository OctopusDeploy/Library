'use strict';

import React from 'react';
import ReactDOM from 'react-dom';
import {match, Router} from 'react-router';
import createBrowserHistory from 'history/lib/createBrowserHistory';
import createMemoryHistory from 'history/lib/createMemoryHistory';

import Analytics from './services/Analytics.js';

let history = createBrowserHistory();

import LibraryActions from './actions/LibraryActions';
import routes from './Routes';

function onRouteChange() {
  Analytics.sendPageView();
}

LibraryActions.sendTemplates(window.stepTemplates, () => {
  ReactDOM.render(
    <Router history={history} onUpdate={onRouteChange}>{routes}</Router>,
    document.getElementById('reactRoot')
  );
});
