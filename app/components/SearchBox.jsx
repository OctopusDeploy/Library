"use strict";

import React from "react";
import PropTypes from "prop-types";

const displayName = "octopus-library-search-box";

export default class SearchBox extends React.Component {
  constructor() {
    super();
    this.handleSearchFilterChange = this.handleSearchFilterChange.bind(this);
  }

  componentDidMount() {
    this._searchFilter.focus();
  }

  handleSearchFilterChange() {
    this.props.handleUserInput(this._searchFilter.value);
  }

  render() {
    let placeholder = "Search " + this.props.templateCount + " community contributed templates...";
    return (
      <section className="template-search">
        <div className="container">
          <div className="row clearfix">
            <div className="column two-thirds">
              <div className="search-box">
                <div className="search-input">
                  <input autoFocus onChange={this.handleSearchFilterChange} placeholder={placeholder} ref={(c) => (this._searchFilter = c)} type="text" value={this.props.filterText} />
                </div>
              </div>
            </div>
            <div className="column third">
              <p className="tutorial">
                <strong>Be part of it!</strong>
                <br /> Submit templates, report issues and send patches at the GitHub <a href="https://github.com/OctopusDeploy/Library">project site</a>.
              </p>
            </div>
          </div>
        </div>
      </section>
    );
  }
}

SearchBox.propTypes = {
  filterText: PropTypes.string,
  handleUserInput: PropTypes.any,
  templateCount: PropTypes.number,
};

SearchBox.defaultProps = {
  filterText: "",
  templateCount: 0,
};

SearchBox.displayName = displayName;
