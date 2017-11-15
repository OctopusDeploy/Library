'use strict';

import React from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';

const displayName = 'octopus-library-template-social-buttons-facebook';

export default class FacebookButton extends React.Component{

  constructor(props) {
    super(props);
    this.state = { initalized : false };
  }

  componentDidMount(){
    this.init();
  }

  componentWillUnmount(){
    let elem = document.getElementById('facebook-jssdk');
    if(elem !== undefined){
      elem.parentNode.removeChild(elem);
    }
  }

  init () {
    if(this.state.initalized){
      return;
    }

    let fbsharebutton = this._fbsharebutton;
    let fbscript = document.createElement('script');
    fbscript.src = '//connect.facebook.net/en_US/sdk.js#xfbml=1&version=v2.5';
    fbscript.id = 'facebook-jssdk';
    fbscript.onload = this.renderWidget.bind(this);
    fbsharebutton.parentNode.appendChild(fbscript);

    this.setState({initalized: true });
  }

  renderWidget(){
      /*
         need to detect if it has already been parsed.
         if coming from react router it may need reparsing.
      */
      setTimeout(function () {
        let elem = document.getElementById('fbsharebutton');
        if(elem.getAttribute('fb-xfbml-state') === null){
          window.FB.XFBML.parse();
        }
      }, 1000);
  }

  render(){
    return (

      <div className="fb-share-button"
          data-layout="button_count"
          id="fbsharebutton"
          ref={(btn) => this._fbsharebutton = btn}
      />
    );

  }
}

FacebookButton.propTypes = {
  url: PropTypes.string
};

FacebookButton.defaultProps = {
  url: ''
};

FacebookButton.displayName = displayName;
