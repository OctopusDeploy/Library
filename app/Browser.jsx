'use strict';

import React from 'react';
import ReactDOM from 'react-dom';
import {match, Router} from 'react-router';
import createBrowserHistory from 'history/lib/createBrowserHistory';
import createMemoryHistory from 'history/lib/createMemoryHistory';

let history = createBrowserHistory();

import LibraryActions from './actions/LibraryActions';
import routes from './Routes';

LibraryActions.sendTemplates(window.stepTemplates, () => {
  ReactDOM.render(
    <Router history={history}>{routes}</Router>,
    document.getElementById('reactRoot')
  );
});
