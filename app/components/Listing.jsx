"use strict";

import React from "react";
import PropTypes from "prop-types";

import SearchBox from "./SearchBox";
import TemplateList from "./TemplateList";
import LibraryStore from "./../stores/LibraryStore";

const displayName = "octopus-library-listing";

export default class Listing extends React.Component {
  constructor(props) {
    super(props);
    this.state = { filterText: this.props.params.searchTerm || "", templates: LibraryStore.getItems() };

    this._handleUserInput = this._handleUserInput.bind(this);
  }

  componentDidMount() {
    LibraryStore.addChangeListener(this._onChange);
  }

  componentWillDismount() {
    LibraryStore.removeChangeListener(this._onChange);
  }

  _onChange() {
    this.setState({
      templates: LibraryStore.getItems(),
    });
  }

  _handleUserInput(filterText) {
    this.setState({
      filterText: filterText,
    });
  }

  render() {
    return (
      <div>
        <SearchBox filterText={this.state.filterText} handleUserInput={this._handleUserInput} templateCount={this.state.templates.length} />
        <TemplateList filterText={this.state.filterText} templateList={this.state.templates} />
      </div>
    );
  }
}

Listing.propTypes = {
  params: PropTypes.object,
};

Listing.defaultProps = {
  params: {},
};

Listing.displayName = displayName;
