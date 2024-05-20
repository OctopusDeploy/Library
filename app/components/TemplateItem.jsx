"use strict";

import React from "react";
import moment from "moment";
import { marked } from "marked";
import DOMPurify from "isomorphic-dompurify";
import SyntaxHighlighter from "react-syntax-highlighter";
import { solarizedLight } from "react-syntax-highlighter/dist/cjs/styles/hljs";
import PropTypes from "prop-types";

import CopyToClipboard from "react-copy-to-clipboard";

import TemplateParameters from "./TemplateParameters";
import TemplateBody from "./TemplateBody";

import LibraryStore from "./../stores/LibraryStore";
import Analytics from "./../services/Analytics.js";

const displayName = "octopus-library-template-item";

export default class TemplateItem extends React.Component {
  constructor(props) {
    super(props);
    let template = LibraryStore.get(this.props.params.friendlySlugOrId) || LibraryStore.getByFriendlySlug(this.props.params.friendlySlugOrId);

    this.state = {
      copied: false,
      template: template,
      showJsonBlob: false,
    };
  }

  handleCopied(event) {
    this.setState({
      copied: true,
    });
    Analytics.sendEvent("template", "copied", this.state.template.Id);
  }

  rawMarkup() {
    let purifiedDescription = DOMPurify.sanitize(this.state.template.Description);
    let markup = marked.parse(purifiedDescription || "");
    return { __html: markup };
  }

  toJson(val) {
    let jsonString = JSON.stringify(val, null, 2);
    return jsonString;
  }

  toggleJsonBlob() {
    this.setState({
      showJsonBlob: !this.state.showJsonBlob,
    });
  }

  getJsonBlobHeight() {
    if (this.state.showJsonBlob) {
      return "9000px";
    } else {
      return "0px";
    }
  }

  render() {
    var style = { maxHeight: this.getJsonBlobHeight() };
    return (
      <div className="container">
        <div className="step-template">
          <div className="row clearfix">
            <div className="column two-thirds">
              <img className="logo" src={"data:image/gif;base64," + this.state.template.Logo} />
              <h2 className="name">{this.state.template.Name}</h2>
              <p className="who-when faint no-top-margin">
                <i>{this.state.template.ActionType}</i> exported {moment(this.state.template.ExportedAt).calendar()} by
                <a className="author faint" href={`https://github.com/${this.state.template.Author}`}>
                  {" "}
                  {this.state.template.Author}
                </a>{" "}
                belongs to '{this.state.template.Category}' category.
              </p>
              <span className="template-description" dangerouslySetInnerHTML={this.rawMarkup()} />
              <TemplateParameters parameters={this.state.template.Parameters} />
              <TemplateBody
                actionType={this.state.template.ActionType}
                scriptSyntax={this.state.template.Properties["Octopus.Action.Script.Syntax"] || ""}
                templateBody={
                  this.state.template.Properties["Octopus.Action.Script.ScriptBody"] ||
                  this.state.template.Properties["Octopus.Action.Email.Body"] ||
                  this.state.template.Properties["Octopus.Action.Azure.ResourceGroupTemplate"] ||
                  this.state.template.Properties["Octopus.Action.KubernetesContainers.CustomResourceYaml"] ||
                  this.state.template.Properties["Octopus.Action.Terraform.Template"]
                }
              />
            </div>
            <div className="column third">
              <p className="tutorial">
                To use this template in Octopus Deploy, copy the JSON below and paste it into the <em>Library &rarr; Step templates &rarr; Import</em> dialog.
              </p>
              <CopyToClipboard onCopy={this.handleCopied.bind(this)} text={this.toJson(this.state.template)}>
                <button className={"button success full-width" + (this.state.copied ? " copied" : "")} type="button">
                  Copy to clipboard
                </button>
              </CopyToClipboard>
              <p className={"faint full-width centered" + (this.state.copied ? "" : " hidden")}>
                <strong>Copied!</strong>
              </p>
              <a className="faint" onClick={this.toggleJsonBlob.bind(this)}>
                {this.state.showJsonBlob ? "Hide" : "Show"} JSON
              </a>
              <div className="templateContent" style={style}>
                <SyntaxHighlighter language="json" style={solarizedLight}>
                  {this.toJson(this.state.template)}
                </SyntaxHighlighter>
              </div>
              <p className="align-right">
                <a className="faint" href={this.state.template.HistoryUrl}>
                  History &raquo;
                </a>
              </p>
            </div>
            <div className="row clearfix">
              <div className="column full">
                <p className="faint">
                  Provided under the
                  <a className="faint" href="https://github.com/OctopusDeploy/Library/blob/master/LICENSE.txt">
                    {" "}
                    Apache License version 2.0
                  </a>
                  .
                </p>
                <div className="social-buttons">
                  <button className="github-button" id="github-button">
                    <a href={`https://github.com/OctopusDeploy/Library/issues/new?assignees=&labels=&projects=&template=bug-report.yml&title=Issue%20with%20${this.state.template.Name}&step-template=${this.state.template.Name}`} target="_blank">
                      <i className="fa fa-github fa-lg" />
                      &nbsp;Report Issue
                    </a>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }
}

TemplateItem.displayName = displayName;

TemplateItem.propTypes = {
  params: PropTypes.object,
};

TemplateItem.defaultProps = {
  params: {},
};
