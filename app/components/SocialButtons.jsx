'use strict';

import React from 'react';

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
  url: React.PropTypes.string
};

SocialButtons.defaultProps = {
  url: ''
};

SocialButtons.displayName = displayName;
