'use strict';

import React from 'react';
import {Router, IndexRedirect, Route} from 'react-router/umd/ReactRouter';

import App from './components/App';
import Listing from './components/Listing';
import TemplateItem from './components/TemplateItem';
import LibraryStore from './stores/LibraryStore';

const redirect = (nextState, replace, callback) => {
    let template = LibraryStore.getByFriendlySlug(nextState.params.friendlySlugOrId);
    if (template) {
      replace(`step-template/${template.Id}/${nextState.params.friendlySlugOrId}`);
    }

    callback();
};

let routes = (
  <Route component={App}
      path="/"
  >
    <IndexRedirect to="listing" />
    <Route component={Listing}
        path="listing(/:searchTerm)"
    />
    <Route component={TemplateItem}
        path="step-template/:templateId/:friendlySlug"
    />
    <Route component={TemplateItem}
       onEnter={redirect}
       path="step-template/:friendlySlugOrId"
    />
  </Route>
);

export default routes;
