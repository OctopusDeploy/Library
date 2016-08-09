var fs = require('fs');

describe("step-templates", function() {
  beforeEach(function(){
    jasmine.addMatchers({
      toHaveValidLastModified: function() {
        return {
          compare: function(template){
            if(typeof template.LastModifiedBy == 'undefined')  {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have a valid LastModifiedBy field, but it was undefined.' }
            } else if(typeof template.$Meta.ExportedAt == 'undefined')  {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have a valid ExportedAt date, but it was undefined.' }
            } else {
              return { pass: true, message: 'Expected template "' + template.Name + '" to have a valid LastModifiedBy field.' }
            }
          }
        }
      }
    });
  });

  it("step templates have valid last modified details", function(done) {
    var filenameCounter = 0;
    var stepTemplateCount = 0;
    var dirname = './step-templates/';

    fs.readdir(dirname, function(err, filenames) {
      if (err) {
        console.log('error listing files in dir: ' + err);
        return;
      }
      stepTemplateCount = filenames.length;
      filenames.forEach(function(filename) {
        fs.readFile(dirname + filename, 'utf-8', function(err, content) {
          if (err) {
            console.log('error reading file ' + filename + ': ' + err);
            return;
          }
          try {
            var template = JSON.parse(content);
            expect(template).toHaveValidLastModified();
          }
          catch(e) {
            console.log('error reading file ' + dirname + filename + ': ' + e + ' - it might be UTF 8 with a BOM. Please resave without the BOM.')
          }
          if (++filenameCounter == stepTemplateCount) {
            done();
          };
        });
      });
    });
  });
});
