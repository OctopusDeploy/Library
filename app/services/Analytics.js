"use strict";

class Analytics {
  sendPageView() {
    console.log(`Sending page view of page '${document.location.pathname}'`);
    window.ga("send", "pageview", document.location.pathname);
  }

  sendEvent(category, name, value) {
    console.log(`Sending '${category}' event named '${name}' with value '${value}'`);
    window.ga("send", "event", category, name, value);
  }
}

export default new Analytics();
