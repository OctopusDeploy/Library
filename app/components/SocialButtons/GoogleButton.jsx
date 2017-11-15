'use strict';

import React from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';

const displayName = 'octopus-library-template-social-buttons-google';

export default class GoogleButton extends React.Component{

  constructor(props) {
    super(props);
    this.state = { initalized : false };
  }

  componentDidMount(){
    this.init();
  }

  componentWillUnmount(){
    let elem = document.getElementById('gapi');
    if(elem !== undefined){
      elem.parentNode.removeChild(elem);
    }
  }

  init () {
    if(this.state.initalized){
      return;
    }

    let gpbutton = this._gpbutton;
    let gpscript = document.createElement('script');
    gpscript.src = '//apis.google.com/js/platform.js';
    gpscript.id = 'gapi';
    gpscript.onload = this.renderWidget.bind(this);
    gpbutton.parentNode.appendChild(gpscript);

    this.setState({initalized: true });
  }

  renderWidget(){
    window.gapi.plusone.render('gpbutton');
  }

  render(){
    return (

      <div
          className="g-plus"
          data-action="share"
          data-annotation="bubble"
          id="gpbutton"
          ref={(btn) => this._gpbutton = btn}
      />
    );

  }
}

GoogleButton.propTypes = {
  url: PropTypes.string
};

GoogleButton.defaultProps = {
  url: ''
};

GoogleButton.displayName = displayName;
