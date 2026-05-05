# Define variables
channel=$(get_octopusvariable "ssn_Channel")
username=$(get_octopusvariable "ssn_Username")
icon_url=$(get_octopusvariable "ssn_IconUrl")
parse="full"
pretext=$(get_octopusvariable "ssn_Title")
text=$(get_octopusvariable "ssn_Message")
color=$(get_octopusvariable "ssn_Color")
webook_url=$(get_octopusvariable "ssn_HookUrl")

# Create JSON payload
json_payload='{"username": '
json_payload+="\"$username\""
json_payload+=', "parse": '
json_payload+="\"$parse\""
json_payload+=', "channel": '
json_payload+="\"$channel\""
json_payload+=', "icon_url": '
json_payload+="\"$icon_url\""
json_payload+=', "attachments" : [{"text": '
json_payload+="\"$text\""
json_payload+=', "color": '
json_payload+="\"$color\""
json_payload+=', "pretext": '
json_payload+="\"$pretext\""
json_payload+=', "mrkdwn_in": ["pretext","text"]}]}'

# Send webhook - redirect stderr to stdout
wget --post-data="$json_payload" --secure-protocol="auto" "$webook_url" 2>&1

# Check for error
if [[ $? -ne 0 ]]
then
    fail_step "Failed!"
fi