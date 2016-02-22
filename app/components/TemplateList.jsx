'use strict';

import React from 'react';
import moment from 'moment';
import {Link} from 'react-router';

const displayName = 'octopus-library-template-list';

export default class TemplateList extends React.Component {
  render() {
    let templateList = this.props.templateList.map((item, index) => {
      if(item.Name.toLowerCase().indexOf(this.props.filterText.toLowerCase()) === -1) {
        return;
      }
      let formattedExportedAt = moment(item.ExportedAt).calendar();

      return (
        <li className={'item-summary ' + item.ScriptClass}
            key={index + '.' + item.Name}
        >
          <h4 key={index + '.' + item.Name + '.0'}>
            <Link to={`/step-template/${item.Id}`}>{item.Name}</Link>
          </h4>
          <p className="faint">Exported {formattedExportedAt} by <strong>{item.Author}</strong></p>
        </li>
      );
    });

    return (
      <div className="template-list">
        <div className="container">
          <div className="row clearfix">
            <div className="column full">
              <ul className="search-results">
                {templateList}
              </ul>
            </div>
          </div>
        </div>
      </div>
    );
  }
}

TemplateList.propTypes = {
  filterText: React.PropTypes.string,
  templateList: React.PropTypes.array
};

TemplateList.defaultProps = {
  filterText: '',
  templateList: []
};

TemplateList.displayName = displayName;
