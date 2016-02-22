'use strict';

import React from 'react';
import {Link} from 'react-router';

const displayName = 'octopus-library-header';

export default class Header extends React.Component {
  render() {
    return (
      <header>
        <h2 className="site-title"><Link to="/">Octopus Deploy Library</Link></h2>
      </header>
    );
  }
}

Header.displayName = displayName;
