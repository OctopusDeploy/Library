import os
import re
import http.client
import json
import time
from urllib.parse import quote

# If this script is not being run as part of an Octopus step, return variables from environment variables.
# Periods are replaced with underscores, and the variable name is converted to uppercase
if 'get_octopusvariable' not in globals():
    def get_octopusvariable(variable):
        return os.environ.get(re.sub('\\.', '_', variable.upper()))

if 'set_octopusvariable' not in globals():
    def set_octopusvariable(variable, value):
        print(f"Setting {variable} to {value}")

# If this script is not being run as part of an Octopus step, print directly to std out.
if 'printverbose' not in globals():
    def printverbose(msg):
        print(msg)

def make_post_request(message, auto_approve, github_token, octopus_api_key, octopus_server, retry = 0):
    """
    Query the Octopus AI service with a message.
    :param message: The prompt message
    :param github_token: The GitHub token
    :param octopus_api_key: The Octopus API key
    :param octopus_server: The Octopus URL
    :return: The AI response
    """
    headers = {
        "X-GitHub-Token": github_token,
        "X-Octopus-ApiKey": octopus_api_key,
        "X-Octopus-Server": octopus_server,
        "Content-Type": "application/json"
    }
    body = json.dumps({"messages": [{"content": message}]}).encode("utf8")

    conn = http.client.HTTPSConnection("aiagent.octopus.com", timeout=240)
    conn.request("POST", "/api/form_handler", body, headers)
    response = conn.getresponse()
    response_data = response.read().decode("utf8")
    conn.close()

    if response.status < 200 or response.status > 300:
        if retry < 2:
            printverbose(f"Request to AI Agent failed with status code {response.status} and message: {response.reason}. Retrying...")
            time.sleep(400)
            return make_post_request(message, auto_approve, github_token, octopus_api_key, octopus_server, retry + 1)
        return f"Request to AI Agent failed with status code {response.status} and message: {response.reason}"

    if is_action_response(response_data):
        if auto_approve:
            id = action_response_id(response_data)

            if not id:
                return "Prompt required approval, but no confirmation ID was found in the response."

            conn = http.client.HTTPSConnection("aiagent.octopus.com", timeout=240)
            conn.request("POST", "/api/form_handler?confirmation_id=" + quote(id, safe='') + "&confirmation_state=accepted", body, headers)
            response = conn.getresponse()
            response_data = response.read().decode("utf8")
            conn.close()
            return convert_from_sse_response(response_data)
        else:
            return "Prompt required approval, but auto-approval is disabled. Please enable the auto-approval option in the step."

    return convert_from_sse_response(response_data)


def convert_from_sse_response(sse_response):
    """
    Converts an SSE response into a string.
    :param sse_response: The SSE response to convert.
    :return: The string representation of the SSE response.
    """

    responses = map(
        lambda line: json.loads(line.replace("data: ", "")),
        filter(lambda line: line.strip().startswith("data:"), sse_response.split("\n")),
    )
    content_responses = filter(
        lambda response: "content" in response["choices"][0]["delta"], responses
    )
    return "\n".join(
        map(
            lambda line: line["choices"][0]["delta"]["content"].strip(),
            content_responses,
        )
    )

def is_action_response(sse_response):
    responses = map(
        lambda line: json.loads(line.replace("data: ", "")),
        filter(lambda line: line.strip().startswith("data:"), sse_response.split("\n")),
    )

    return any(response.get("type") == "action" for response in responses)

def action_response_id(sse_response):
    responses = map(
        lambda line: json.loads(line.replace("data: ", "")),
        filter(lambda line: line.strip().startswith("data:"), sse_response.split("\n")),
    )

    action = next(filter(lambda response: response.get("type") == "action", responses))

    return action.get("confirmation", {}).get("id")

step_name = get_octopusvariable("Octopus.Step.Name")
message = get_octopusvariable("OctopusAI.Prompt")
github_token = get_octopusvariable("OctopusAI.GitHub.Token")
octopus_api = get_octopusvariable("OctopusAI.Octopus.APIKey")
octopus_url = get_octopusvariable("OctopusAI.Octopus.Url")
auto_approve = get_octopusvariable("OctopusAI.AutoApprove").casefold() == "true"

result = make_post_request(message, auto_approve, github_token, octopus_api, octopus_url)

set_octopusvariable("AIResult", result)

print(result)
print(f"AI result is available in the variable: Octopus.Action[{step_name}].Output.AIResult")
