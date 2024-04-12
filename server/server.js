"use strict";

import express from "express";
import path from "path";
import compress from "compression";

import React from "react";
import ReactDOMServer from "react-dom/server";
import { match, RouterContext } from "react-router";

import "@babel/register";
import frameguard from "frameguard";

import config from "./package.json";
import App from "./app/components/App";
import routes from "./app/Routes";
import LibraryStorageService from "./app/services/LibraryDb.js";
import LibraryActions from "./app/actions/LibraryActions";

let app = express();

app.use(express.static(path.join(__dirname, "public"), { maxage: "1d" }));
app.use(express.static(path.join(__dirname, "views"), { maxage: "1d" }));
app.use("/.well-known", express.static(".well-known"));

app.set("views", path.join(__dirname, "views"));
app.set("view engine", "pug");

app.use(compress());
app.use(frameguard({ action: "deny" }));

app.disable("view cache");

app.get("/api/step-templates", (req, res) => {
  LibraryStorageService.list((err, data) => {
    if (err !== null) {
      console.error(err);
      res.send("Error: " + err);
      res.end();
      return;
    }

    res.send(data);
  });
});

app.get("/api/step-templates/:id", (req, res) => {
  LibraryStorageService.get(req.params.id, (err, data) => {
    if (err !== null) {
      console.error(err);
      res.send("Error: " + err);
      res.end();
      return;
    }

    res.send(data);
  });
});

app.get("*", (req, res) => {
  match({ routes, location: req.url }, (error, redirectLocation, renderProps) => {
    if (error) {
      res.status(500).send(error.Message);
    } else if (redirectLocation) {
      res.redirect(302, redirectLocation.pathname + redirectLocation.search);
    } else if (renderProps) {
      LibraryStorageService.list((err, data) => {
        if (err !== null) {
          console.error(err);
          res.send("Error: " + err);
          res.end();
          return;
        }

        LibraryActions.sendTemplates(data, () => {
          var libraryAppHtml = ReactDOMServer.renderToStaticMarkup(<RouterContext {...renderProps} />);
          res.render("index", {
            siteKeywords: config.keywords.join(),
            siteDescription: config.description,
            reactOutput: libraryAppHtml,
            stepTemplates: JSON.stringify(data),
          });
        });
      });
    }
  });
});

let port = process.env.PORT || 9000;
let server = app.listen(port, function () {
  let host = server.address().address;
  let serverPort = server.address().port;
  console.log(`NODE_ENV: ${process.env.NODE_ENV}`);
  console.log(`Server listening on http://${host}:${serverPort}`);
});
