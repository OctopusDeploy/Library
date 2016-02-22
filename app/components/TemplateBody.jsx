'use strict';

import React from 'react';

const displayName = 'octopus-library-template-body';

export default class TemplateBody extends React.Component {
  render() {
    switch(this.props.actionType) {
      case 'Octopus.Script':
        return (
          <div>
            <h3>Script body</h3>
            <p className="tutorial">
              Steps based on this template will execute the following <em>PowerShell</em> script.
            </p>
            <pre className="code scroll">{this.props.templateBody}</pre>
          </div>
        );
      case 'Octopus.Email':
        return (
          <div>
            <h3>Email body</h3>
            <p className="tutorial">
              Steps based on this template will render the email body below.
            </p>
            <pre className="code scroll">{this.props.templateBody}</pre>
          </div>
        );
      default:
        return <div></div>;
    }
  }
}

TemplateBody.displayName = displayName;

TemplateBody.propTypes = {
  actionType: React.PropTypes.string,
  templateBody: React.PropTypes.string
};

TemplateBody.defaultProps = {
  templateBody: ''
};
