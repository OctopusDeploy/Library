"use strict";

import React from "react";
import { marked } from "marked";
import PropTypes from "prop-types";
import DOMPurify from "isomorphic-dompurify";

const displayName = "octopus-library-template-parameters";

export default class TemplateParameters extends React.Component {
  constructor(props) {
    super(props);
    this.state = { showParameterList: false };
  }

  rawMarkup(text) {
    let purifiedText = DOMPurify.sanitize(text);
    let markup = marked.parse(purifiedText || "");
    return { __html: markup };
  }

  toggleParameterList() {
    this.setState({
      showParameterList: !this.state.showParameterList,
    });
  }

  getParameterListHeight() {
    if (this.state.showParameterList) {
      return "9000px";
    } else {
      return "0px";
    }
  }

  render() {
    if (this.props.parameters.length === 0) {
      return <div />;
    }
    let parameterList = this.props.parameters.map((item, index) => {
      return (
        <div className="step-template-parameter" key={index}>
          <h4>{item.Label || item.Name}</h4>
          <div className="name-as-variable">
            <span className="code">
              <span>{item.Name}</span>
              {item.DefaultValue && item.DefaultValue.length > 0 ? <span> = {item.DefaultValue}</span> : <span />}
            </span>
          </div>
          <span className="parameter-help" dangerouslySetInnerHTML={this.rawMarkup(item.HelpText)} />
        </div>
      );
    });
    var style = { maxHeight: this.getParameterListHeight() };
    return (
      <div>
        <h3>Parameters</h3>
        <p className="tutorial">When steps based on the template are included in a project's deployment process, the parameters below can be set.</p>
        {parameterList}
      </div>
    );
  }
}

TemplateParameters.displayName = displayName;

TemplateParameters.propTypes = {
  parameters: PropTypes.array,
};

TemplateParameters.defaultProps = {
  parameters: [],
};
