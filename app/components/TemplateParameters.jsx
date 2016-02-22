'use strict';

import React from 'react';
import marked from 'marked';

const displayName = 'octopus-library-template-parameters';

export default class TemplateParameters extends React.Component {
  rawMarkup(text) {
    let markup = marked((text || ''), {sanitize: true});
    return { __html: markup };
  }

  render() {
    if(this.props.parameters.length === 0) {
      return;
    }
    let parameterList = this.props.parameters.map((item, index) => {
      return (
        <div className="step-template-parameter"
            key={index}
        >
          <h4>{item.Label || item.Name}</h4>
          <div className="name-as-variable"><span className="code"><span>{item.Name}</span>{(item.DefaultValue && item.DefaultValue.length > 0) ? <span> = {item.DefaultValue}</span> : <span></span>}</span></div>
          <span className="parameter-help"
              dangerouslySetInnerHTML={this.rawMarkup(item.HelpText)}
          />
        </div>
      );
    });

    return (
      <div>
        <h3>Parameters</h3>
        <p className="tutorial">
            When steps based on the template are included in a project's deployment process, the parameters below can be set.
        </p>
        {parameterList}
      </div>
    );
  }
}

TemplateParameters.displayName = displayName;

TemplateParameters.propTypes = {
  parameters: React.PropTypes.array
};

TemplateParameters.defaultProps = {
  parameters: []
};
