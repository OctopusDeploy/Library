'use strict';

import React from 'react';

const displayName = 'octopus-library-template-body';

export default class TemplateBody extends React.Component {
  constructor(props) {
    super(props);
    this.state = { showTemplateBody: false };
  }

  toggleTemplateBody() {
    this.setState({
      showTemplateBody: !this.state.showTemplateBody
    });
  }

  getTemplateBodyHeight() {
    if (this.state.showTemplateBody) {
      return '9000px';
    } else {
      return '0';
    }
  }

  render() {
    var header = '';
    var description = '';

    switch (this.props.actionType) {
      case 'Octopus.Script':
        header = 'Script body';
        description = 'Steps based on this template will execute the following <em>PowerShell</em> script.';
        break;
      case 'Octopus.Email':
        header = 'Email body';
        description = 'Steps based on this template will render the email body below.';
        break;
      default:
        return <div></div>;
    }
    var style = { maxHeight: this.getTemplateBodyHeight() };
    return (
      <div>
        <h3>{header}</h3>
        <p className="tutorial">
          <div dangerouslySetInnerHTML={ { __html: description } }></div>
          <a className="faint"
            onClick={this.toggleTemplateBody.bind(this) }
            >
            {this.state.showTemplateBody ? 'Hide' : 'Show '} script
          </a>
        </p>
        <div className="templateContent" style={style}>
          <pre className="code scroll">{this.props.templateBody}</pre>
        </div>
      </div>
    );
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
