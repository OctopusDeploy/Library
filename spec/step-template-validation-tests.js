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
      },
      toHaveValidName: function() {
        return {
          compare: function(template){
            if(!template.Name)  {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have Name specified.' }
            } else if(template.Name.length > 200)  {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have Name shorter than 200 characters.' }
            } else {
              return { pass: true, message: '' }
            }
          }
        }
      },
      toHaveValidId: function() {
        return {
          compare: function(template){
            if(!template.Id)  {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have Id specified.' }
            } else if(!(new RegExp(".{8}-.{4}-.{4}-.{4}-.{12}").test(template.Id))) {
              return { pass: false, message: 'Expected template "' + template.Name + '" to have Id "' + template.Id + '" in a form of a GUID: 00000000-0000-0000-0000-000000000000 .' }
            } else {
              return { pass: true, message: '' }
            }
          }
        }
      }
    });
  });

  it("step templates have valid details", function(done) {
    var filenameCounter = 0;
    var stepTemplateCount = 0;
    var dirname = './step-templates/';

    fs.readdir(dirname, function(err, filenames) {
      if (err) {
        console.log('error listing files in dir: ' + err);
        return;
      }

      filenames =  filenames.filter(function(file) { return file.substr(-5) === '.json'; })
      stepTemplateCount = filenames.length;

      var names = [];
      var ids = [];

      filenames.forEach(function(filename) {

        fs.readFile(dirname + filename, 'utf-8', function(err, content) {
          if (err) {
            fail('error reading file ' + filename + ': ' + err);
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

          }
          catch(e) {
            fail('error reading file ' + dirname + filename + ': ' + e + ' - it might be UTF 8 with a BOM. Please resave without the BOM.')
          }
          if (++filenameCounter == stepTemplateCount) {
            done();
          };
        });
      });
    });
  });
});
