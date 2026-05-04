var fs = require("fs");

describe("logos", function () {
  it("logos have valid details", function (done) {
    var sourceDirname = "./src/step-templates/logos";
    var legacyDirname = "./step-templates/logos";
    var dirname = fs.existsSync(sourceDirname) ? sourceDirname : legacyDirname;

    fs.readdir(dirname, function (err, filenames) {
      if (err) {
        console.log("error listing files in dir: " + err);
        return;
      }

      filenames.forEach(function (filename) {
        var extension = filename.substring(filename.length - 4);
        expect(extension).toBe(".png");
      });

      done();
    });
  });
});
