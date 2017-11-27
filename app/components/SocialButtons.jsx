'use strict';

import React from 'react';
import PropTypes from 'prop-types';

import FacebookButton from './SocialButtons/FacebookButton';
import GoogleButton from './SocialButtons/GoogleButton';
import TwitterButton from './SocialButtons/TwitterButton';

const displayName = 'octopus-library-template-social-buttons';

export default class SocialButtons extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return (
      <div className="social-buttons">
        <GoogleButton />
        <TwitterButton />
        <FacebookButton />
      </div>
    );
  }
}

SocialButtons.propTypes = {
  url: PropTypes.string
};

SocialButtons.defaultProps = {
  url: ''
};

SocialButtons.displayName = displayName;
