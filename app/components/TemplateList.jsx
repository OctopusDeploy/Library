"use strict";

import React from "react";
import moment from "moment";
import { Link } from "react-router";
import SlugMaker from "./../services/SlugMaker";
import PropTypes from "prop-types";
import { marked } from "marked";
import DOMPurify from "isomorphic-dompurify";

const displayName = "octopus-library-template-list";

export default class TemplateList extends React.Component {
  markdown(description) {
    let firstLine = (description || "").split(/\r?\n|\r|\n/g)[0];
    let purifiedDescription = DOMPurify.sanitize(firstLine);
    let markup = marked.parse(purifiedDescription || "");
    return { __html: markup };
  }

  render() {
    let templateList = this.props.templateList.map((item, index) => {
      let lc = this.props.filterText.toLowerCase();
      if (item.Name.toLowerCase().indexOf(lc) === -1 && (item.Description === null || item.Description.toLowerCase().indexOf(lc) === -1)) {
        return;
      }
      let friendlySlug = SlugMaker.make(item.Name);
      return (
        <li className={"item-summary " + (item.ScriptClass || "")} key={index + "." + item.Name}>
          <img src={"data:image/gif;base64," + item.Logo} />
          <h4 key={index + "." + item.Name + ".0"}>
            <Link to={`/step-templates/${item.Id}/${friendlySlug}`}>{item.Name}</Link>
          </h4>
          <div className="faint" dangerouslySetInnerHTML={this.markdown(item.Description)} />
        </li>
      );
    });

    return (
      <div className="template-list">
        <div className="container">
          <div className="row clearfix">
            <div className="column full">
              <ul className="search-results">{templateList}</ul>
            </div>
          </div>
        </div>
      </div>
    );
  }
}

TemplateList.propTypes = {
  filterText: PropTypes.string,
  templateList: PropTypes.array,
};

TemplateList.defaultProps = {
  filterText: "",
  templateList: [],
};

TemplateList.displayName = displayName;
