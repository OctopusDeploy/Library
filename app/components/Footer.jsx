"use strict";

import React from "react";

const displayName = "octopus-library-footer";

export default class Footer extends React.Component {
  render() {
    return (
      <footer>
        <div className="row clearfix">
          <div className="column full centered">
            <p>
              The Octopus Deploy Library is a way for users of <a href="https://octopus.com">Octopus Deploy</a> to share useful code.
            </p>
            <p>
              Need help? Feel free to contact the team via our&nbsp;
              <a href="https://help.octopus.com/" target="_blank">
                support forum
              </a>
              .
            </p>
            <span>
              Built with <i className="fa fa-heart fa-fw" /> by the <div className="icon-octopus">team</div>
            </span>
            <ul>
              <li>
                <a href="https://twitter.com/OctopusDeploy">
                  <i className="fa fa-twitter fa-fw" />
                </a>
              </li>
              <li>
                <a href="http://feeds.feedburner.com/OctopusDeploy">
                  <i className="fa fa-rss fa-fw" />
                </a>
              </li>
            </ul>
          </div>
        </div>
      </footer>
    );
  }
}

Footer.displayName = displayName;
