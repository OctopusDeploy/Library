"use strict";

import React from "react";
import PropTypes from "prop-types";

import FacebookButton from "./SocialButtons/FacebookButton";
import TwitterButton from "./SocialButtons/TwitterButton";

const displayName = "octopus-library-template-social-buttons";

export default class SocialButtons extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return (
      <div className="social-buttons">
        <TwitterButton />
        <FacebookButton />
        <button className="github-button" id="github-button">
          <a href="https://github.com/OctopusDeploy/Library/issues/new" target="_blank">
            <i className="fa fa-github fa-lg" />
            &nbsp;Report issue
          </a>
        </button>
      </div>
    );
  }
}

SocialButtons.propTypes = {
  url: PropTypes.string,
};

SocialButtons.defaultProps = {
  url: "",
};

SocialButtons.displayName = displayName;
