import json
from jsonschema import validate

def validateJSON(jsonData):
    try:
        #jsonData must be STRING type
        json.loads(jsonData)
    except Exception as e:
        #print(str(e))
        #print(e.message)
        return str(e)
    return None

def validateSchema(jsonData, jsonSchema):
    try:
        validate(instance=json.loads(jsonData), schema=json.loads(jsonSchema))
    except Exception as e:
        #print(e.message)
        #print(str(e))
        return e.message
    return None

vSchema = get_octopusvariable("vSchema")
vJsonData = get_octopusvariable("vJsonData")

vError = validateJSON(vJsonData)
if vError == None:
   vRslt = 'Correct!'
   print('JSON Structure is valid !','\n')

   if vSchema:
      vError = validateSchema(vJsonData, vSchema)
      if vError == None:
         vRslt = 'Correct!'
         print('JSON Schema is valid !','\n')
      else:
         vRslt = 'Wrong !'        
         print('JSON Schema error:', vError, file=sys.stderr)
else:
    vRslt = 'Wrong!'
    print('JSON structure error:', vError, file=sys.stderr)

print ('Result:', vRslt)