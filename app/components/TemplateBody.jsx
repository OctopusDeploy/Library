"use strict";

import React from "react";
import SyntaxHighlighter from "react-syntax-highlighter";
import { solarizedLight } from "react-syntax-highlighter/dist/cjs/styles/hljs";
import PropTypes from "prop-types";

const displayName = "octopus-library-template-body";

export default class TemplateBody extends React.Component {
  constructor(props) {
    super(props);
    this.state = { showTemplateBody: false };
  }

  toggleTemplateBody() {
    this.setState({
      showTemplateBody: !this.state.showTemplateBody,
    });
  }

  getTemplateBodyHeight() {
    if (this.state.showTemplateBody) {
      return "9000px";
    } else {
      return "0px";
    }
  }

  render() {
    var header = "";
    var description = "";
    var language = "";
    var templateType = "script";

    switch (this.props.actionType) {
      case "Octopus.AwsRunScript":
      case "Octopus.AzurePowerShell":
      case "Octopus.GoogleCloudScripting":
      case "Octopus.Script":
      case "Octopus.KubernetesRunScript":
        language = this.props.scriptSyntax;
        header = "Script body";
        description = "Steps based on this template will execute the following <em>" + language + "</em> script.";
        break;
      case "Octopus.AzureResourceGroup":
        language = "json";
        header = "ARM template";
        templateType = "JSON source";
        description = "Steps based on this template will deploy the following template source.";
        break;
      case "Octopus.KubernetesDeployRawYaml":
        language = "yaml";
        header = "YAML body";
        templateType = "YAML source";
        description = "Steps based on this template will deploy the following YAML source.";
        break;
      case "Octopus.Email":
        header = "Email body";
        templateType = "Email source";
        description = "Steps based on this template will render the email body below.";
        break;
      case "Octopus.TerraformApply":
        language = "hcl";
        header = "Terraform resources";
        templateType = "Terraform";
        description = "Steps based on this template will apply the following terraform resources.";
        break;
      default:
        return <div />;
    }
    var style = { maxHeight: this.getTemplateBodyHeight() };
    return (
      <div>
        <h3>{header}</h3>
        <div className="tutorial">
          <div dangerouslySetInnerHTML={{ __html: description }} />
          <a className="showHideScript" onClick={this.toggleTemplateBody.bind(this)}>
            {this.state.showTemplateBody ? "Hide" : "Show"} {templateType}
          </a>
        </div>
        <div className="templateContent" style={style}>
          <SyntaxHighlighter language={language} style={solarizedLight}>
            {this.props.templateBody}
          </SyntaxHighlighter>
        </div>
      </div>
    );
  }
}

TemplateBody.displayName = displayName;

TemplateBody.propTypes = {
  actionType: PropTypes.string,
  scriptSyntax: PropTypes.string,
  templateBody: PropTypes.string,
};

TemplateBody.defaultProps = {
  templateBody: "",
};
