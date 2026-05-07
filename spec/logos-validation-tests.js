var fs = require("fs");

describe("logos", function () {
  it("logos have valid details", function (done) {
    var filenames = [];

    if (fs.existsSync("./step-templates/logos")) {
      filenames = filenames.concat(fs.readdirSync("./step-templates/logos"));
    }

    if (fs.existsSync("./src/step-templates")) {
      fs.readdirSync("./src/step-templates").forEach(function (templateName) {
        var logoPath = "./src/step-templates/" + templateName + "/logo.png";
        if (fs.existsSync(logoPath)) {
          filenames.push("logo.png");
        }
      });
    }

    filenames.forEach(function (filename) {
      var extension = filename.substring(filename.length - 4);
      expect(extension).toBe(".png");
    });

    done();
  });
});
