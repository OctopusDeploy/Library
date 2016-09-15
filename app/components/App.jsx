'use strict';

import React from 'react';
import RouteHandler from 'react-router';

import Header from './Header';
import Listing from './Listing';
import Footer from './Footer';

const displayName = 'octopus-library';

export default class App extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return (
      <div>
        <div className="wrapper">
          <Header />
          <div className="content">
            <section>
              {this.props.children || <Listing />}
            </section>
          </div>
        </div>
        <Footer />
      </div>
    );
  }
}

App.displayName = displayName;

App.propTypes = {
  children: React.PropTypes.object
};

App.defaultProps = {
  children: {}
};
