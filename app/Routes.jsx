"use strict";

import React from "react";
import { Router, IndexRedirect, Route } from "react-router/umd/ReactRouter";

import App from "./components/App";
import Listing from "./components/Listing";
import TemplateItem from "./components/TemplateItem";

let routes = (
  <Route component={App} path="/">
    <IndexRedirect to="listing" />
    <Route component={Listing} path="listing(/:searchTerm)" />
    <Route component={TemplateItem} path="step-template/:friendlySlugOrId(/:friendlySlug)" />
    <Route component={TemplateItem} path="step-templates/:friendlySlugOrId(/:friendlySlug)" />
  </Route>
);

export default routes;
