'use strict';

import React from 'react';

const displayName = 'octopus-library-footer';

export default class Footer extends React.Component {
  render() {
    return (
      <footer>
        <div className="row clearfix">
          <div className="column full centered">
            <p>The Octopus Deploy Library is a way for users of Octopus Deploy to share useful code.</p>
            <p>
              Need help? Feel free to contact the team via our
              <a href="https://help.octopusdeploy.com/"
                  target="_blank"
              > support forum</a>.
            </p>
            <span className="faint">Built with <i className="fa fa-heart fa-fw dark-red"></i> by the <div className="icon-octopus">team</div></span>
            <ul>
              <li><a href="https://twitter.com/OctopusDeploy"><i className="fa fa-twitter fa-fw"></i></a></li>
              <li><a href="https://plus.google.com/102650558422902813929"><i className="fa fa-google-plus fa-fw"></i></a></li>
              <li><a href="http://feeds.feedburner.com/OctopusDeploy"><i className="fa fa-rss fa-fw"></i></a></li>
            </ul>
          </div>
        </div>
      </footer>
    );
  }
}

Footer.displayName = displayName;
