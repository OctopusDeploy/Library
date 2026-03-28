import subprocess
import sys

subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'httplib2', '--disable-pip-version-check'])

# parameters
webhook_url = get_octopusvariable("GoogleChat.SendMessage.WebhookUrl")
message_content = get_octopusvariable("GoogleChat.SendMessage.MessageContent")

if not webhook_url:
  raise ValueError('Webhook url null or empty!')
  
if not message_content:
  raise ValueError('Message content null or empty!')
  
from json import dumps
from httplib2 import Http

app_message = {"text": message_content}
message_headers = {"Content-Type": "application/json; charset=UTF-8"}
http_obj = Http()
response = http_obj.request(
  uri=webhook_url,
  method="POST",
  headers=message_headers,
  body=dumps(app_message),
)
printverbose('Google response:')
printverbose(response)