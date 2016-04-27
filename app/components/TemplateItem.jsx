'use strict';

import React from 'react';
import moment from 'moment';
import marked from 'marked';

import CopyToClipboard from 'react-copy-to-clipboard';

import ReactDisqusThread from 'react-disqus-thread';

import TemplateParameters from './TemplateParameters';
import TemplateBody from './TemplateBody';
import SocialButtons from './SocialButtons';

import LibraryStore from './../stores/LibraryStore';
import Analytics from './../services/Analytics.js';

const displayName = 'octopus-library-template-item';

export default class TemplateItem extends React.Component {
  constructor(props) {
    super(props);
    this.state = {copied: false, template: LibraryStore.get(this.props.params.templateId), showJsonBlob: false};
  }

  handleCopied(event) {
    this.setState({
      copied: true
    });
    Analytics.sendEvent('template', 'copied', this.state.template.Id);
  }

  rawMarkup() {
    let markup = marked((this.state.template.Description || ''), {sanitize: true});
    return { __html: markup };
  }

  toJson(val) {
    let jsonString = JSON.stringify(val, null, 2);
    return jsonString;
  }
  
  toggleJsonBlob() {
    this.setState({
      showJsonBlob: !this.state.showJsonBlob
    });
  }
  
  getJsonBlobHeight() {
    if(this.state.showJsonBlob) {
      return '9000px';
    } else {
      return '0';
    }
  }

  render() {
    var style = { maxHeight: this.getJsonBlobHeight() };
    return (
      <div className="container">
        <div className="step-template">
          <div className="row clearfix">
            <div className="column two-thirds">
              <h2>{this.state.template.Name}</h2>
              <p className="faint no-top-margin">
                <i>{this.state.template.Body.ActionType}</i> exported {moment(this.state.template.ExportedAt).calendar()} by
                <a className="author faint"
                    href={`https://github.com/${this.state.template.Author}`}
                > {this.state.template.Author}
                </a>
              </p>
              <span className="template-description"
                  dangerouslySetInnerHTML={this.rawMarkup()}
              />
              <TemplateParameters parameters={this.state.template.Body.Parameters} />
              <TemplateBody actionType={this.state.template.Body.ActionType}
                  templateBody={this.state.template.Body.Properties['Octopus.Action.Script.ScriptBody'] || this.state.template.Body.Properties['Octopus.Action.Email.Body']}
              />
            </div>
            <div className="column third">
              <p className="tutorial">
                To use this template in Octopus Deploy, copy the JSON below and paste it into the <em>Library > Step templates > Import</em> dialog.
              </p>
              <CopyToClipboard onCopy={this.handleCopied.bind(this)}
                  text={this.toJson(this.state.template.Body)}
              >
                <button className={'button success full-width' + (this.state.copied ? ' copied' : '')}
                    type="button"
                >
                  Copy to clipboard
                </button>
              </CopyToClipboard>
              <p className={'faint full-width centered' + (this.state.copied ? '' : ' hidden')}><strong>Copied!</strong></p>
              <a className="faint" 
                onClick={this.toggleJsonBlob.bind(this)}
                >
                { this.state.showJsonBlob ? 'Hide' : 'Show' } JSON
              </a>
              <div className="templateContent" style={style}>
                <pre className="code scroll">{this.toJson(this.state.template.Body)}</pre>
              </div>
              <p className="align-right">
                <a className="faint"
                    href={`https://github.com/OctopusDeploy/Library/commits/master/step-templates/${this.state.template.Slug}.json`}
                >
                  History &raquo;
                </a>
              </p>
            </div>
            <div className="row clearfix">
              <div className="column full">
                <p className="faint">
                  Provided under the
                  <a className="faint"
                      href="https://github.com/OctopusDeploy/Library/blob/master/LICENSE"
                  > Apache License version 2.0
                  </a>.
                </p>
                <SocialButtons />
                <h3>Comments</h3>
                <ReactDisqusThread identifier={this.state.template.Id}
                    shortname="octolibrary"
                />
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
  params: React.PropTypes.object
};

TemplateItem.defaultProps = {
  params: {}
};
