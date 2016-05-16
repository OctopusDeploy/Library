'use strict';

import React from 'react';
import ReactDOM from 'react-dom';

const displayName = 'octopus-library-template-social-buttons-twitter';

export default class TwitterButton extends React.Component{

  constructor(props) {
    super(props);
    this.state = { initalized : false };
  }

  componentDidMount(){
    this.init();
  }

  componentWillUnmount(){
    let elem = document.getElementById('twitter-wjs');
    if(elem !== undefined){
      elem.parentNode.removeChild(elem);
    }
  }

  init () {
    if(this.state.initalized){
      return;
    }
    var twitterbutton = this._twitterButton;
    var twitterscript = document.createElement('script');
    twitterscript.src = '//platform.twitter.com/widgets.js';
    twitterscript.id = 'twitter-wjs';
    twitterscript.onload = this.renderWidget.bind(this);
    twitterbutton.parentNode.appendChild(twitterscript);

    this.setState({initalized: true });
  }

  renderWidget(){
    let text = '';
    if(this.props.text != undefined){
      text = this.props.text;
    }

    window.twttr.widgets.createShareButton(
      this.props.url,
      this._twitterButton,
      { text: text }
    );
  }

  render(){
    return (
      <a className="twitter-share-button"
          data-via="library-octopusdeploy"
          href="https://twitter.com/share"
          ref={(btn) => this._twitterButton = btn}
      />
    );
  }
}

TwitterButton.propTypes = {
  text: React.PropTypes.string,
  url: React.PropTypes.string
};

TwitterButton.defaultProps = {
  text: '',
  url: ''
};

TwitterButton.displayName = displayName;
