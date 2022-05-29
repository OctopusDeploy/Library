"use strict";

class SlugMaker {
  make(name) {
    return "actiontemplate" + "-" + name.replace(/ - /g, "-").replace(/ /g, "-").toLowerCase();
  }
}

export default new SlugMaker();
