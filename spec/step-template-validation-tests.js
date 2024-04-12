var fs = require("fs");

describe("step-templates", function () {
  beforeEach(function () {
    jasmine.addMatchers({
      toHaveValidLastModified: function () {
        return {
          compare: function (template) {
            if (typeof template.LastModifiedBy == "undefined") {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have a valid LastModifiedBy field, but it was undefined.' };
            } else if (typeof template.$Meta.ExportedAt == "undefined") {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have a valid ExportedAt date, but it was undefined.' };
            } else {
              return { pass: true, message: 'Expected template "' + template.Name + '" to have a valid LastModifiedBy field.' };
            }
          },
        };
      },
      toHaveValidName: function () {
        return {
          compare: function (template) {
            if (!template.Name) {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have Name specified.' };
            } else if (template.Name.length > 200) {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have Name shorter than 200 characters.' };
            } else {
              return { pass: true, message: "" };
            }
          },
        };
      },
      toHaveValidId: function () {
        return {
          compare: function (template) {
            if (!template.Id) {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have Id specified.' };
            } else if (!new RegExp(".{8}-.{4}-.{4}-.{4}-.{12}").test(template.Id)) {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have Id "' + template.Id + '" in a form of a GUID: 00000000-0000-0000-0000-000000000000 .' };
            } else if (template.Id === "00000000-0000-0000-0000-000000000000" || template.Id === "abcdef00-ab00-cd00-ef00-000000abcdef") {
              return {
                pass: false,
                message:
                  'Expected template "' + template.Name + '" to have Id "' + template.Id + '" different than 00000000-0000-0000-0000-000000000000 and abcdef00-ab00-cd00-ef00-000000abcdef. You can use https://www.guidgen.com to generate a new id.',
              };
            } else {
              return { pass: true, message: "" };
            }
          },
        };
      },
    });
  });

  it("have required details", function (done) {
    var filenameCounter = 0;
    var stepTemplateCount = 0;
    var dirname = "./step-templates/";

    fs.readdir(dirname, function (err, results) {
      if (err) {
        console.log("error listing files in dir: " + err);
        return;
      }

      var templateFiles = results.filter(function (file) {
        return file.substr(-5) === ".json";
      });
      stepTemplateCount = templateFiles.length;

      var names = [];
      var ids = [];

      templateFiles.forEach(function (templateFile) {
        fs.readFile(dirname + templateFile, "utf-8", function (err, content) {
          if (err) {
            fail("error reading file " + templateFile + ": " + err);
            return;
          }
          try {
            var template = JSON.parse(content);

            expect(template).toHaveValidLastModified();
            expect(template).toHaveValidName();
            expect(template).toHaveValidId();

            expect(names).not.toContain(template.Name);
            expect(ids).not.toContain(template.Id);

            names.push(template.Name);
            ids.push(template.Id);
          } catch (e) {
            fail("error reading file " + dirname + templateFile + ": " + e + " - it might be UTF 8 with a BOM. Please resave without the BOM.");
          }
          if (++filenameCounter == stepTemplateCount) {
            done();
          }
        });
      });
    });
  });

  it("have correct file extensions", function (done) {
    var dirname = "./step-templates/";

    fs.readdir(dirname, function (err, results) {
      if (err) {
        console.log("error listing files in dir: " + err);
        return;
      }

      var otherThings = results.filter(function (file) {
        var pesterFile = file.endsWith(".ScriptBody.ps1");
        var jsonFile = file.endsWith(".json");
        return !pesterFile && !jsonFile && file !== "logos" && file !== "tests";
      });
      expect(otherThings).toEqual([]);
      done();
    });
  });

  it("do not set a non-variable package feedId", function (done) {
    var fs = require("fs");

    var dirname = "./step-templates/";

    fs.readdir(dirname, function (err, results) {
      if (err) {
        console.log("error listing files in dir: " + err);
        return;
      }

      var templateFiles = results.filter(function (file) {
        return file.substr(-5) === ".json";
      });

      templateFiles.forEach(function (templateFile) {
        fs.readFile(dirname + templateFile, "utf-8", function (err, content) {
          if (err) {
            fail("error reading file " + templateFile + ": " + err);
          }
          try {
            var template = JSON.parse(content);
            if (template.Packages === undefined || template.Packages.length === 0) {
              return;
            } else {
              template.Packages.forEach(function (pkg) {
                if (pkg.FeedId === undefined) return; // undefined ok
                if (pkg.FeedId === null) return; // null ok
                if (pkg.FeedId[0] === "#") return; // variables ok
                if (pkg.FeedId !== null) {
                  fail(`Package FeedId for ${templateFile} should be null, but was: ${pkg.FeedId}`);
                }
              });
            }
          } catch (e) {
            fail("error reading file " + dirname + templateFile + ": " + e + " - it might be UTF 8 with a BOM. Please resave without the BOM.");
          }
        });
      });
      done();
    });
  });
});
