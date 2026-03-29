set -e

TOKEN=$(get_octopusvariable "TesteryToken")
PIPELINE_STAGE=$(get_octopusvariable "TesteryPipelineStage?")
VARIABLES=$(get_octopusvariable "TesteryVariables?")
NAME=$(get_octopusvariable "TesteryName")
KEY=$(get_octopusvariable "TesteryKey")
MAX_PARALLEL=$(get_octopusvariable "TesteryMaximumParallelTestRuns")
FAIL_IF_EXIST=$(get_octopusvariable "TesteryExistsExitCode")
if [ "$FAIL_IF_EXIST" = "True" ] ; then
    EXIST_EXIT=1
else
    EXIST_EXIT=0
fi
VAR_ARGS=()
if [[ -n "$VARIABLES" ]]; then
  mapfile -t VAR_LINES <<< "$VARIABLES"
  for line in "${VAR_LINES[@]}"; do
    [[ -z "$line" ]] && continue
    VAR_ARGS+=("--variable" "$line")
  done
fi

API_URL="https://api.testery.io/api/environments"
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "$API_URL")

HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1)

# Check if the request was successful
if [ "$HTTP_STATUS" -ne 200 ]; then
    echo "Error querying API:"
    echo "Status Code: $HTTP_STATUS"
    echo "Response: $HTTP_BODY"
    exit 1
fi

export PATH="$HOME/.local/bin:$PATH"

# Check if an environment with the key exists using jq
ENVIRONMENT_EXISTS=$(echo "$HTTP_BODY" | jq -r --arg KEY "$KEY" '.[] | select(.key == $KEY) | .key')

if [ -n "$ENVIRONMENT_EXISTS" ]; then
    echo "Environment with key already exists."
    exit $EXIST_EXIT
else
  pip install --user testery --upgrade

  testery create-environment --token $TOKEN \
    --name $NAME \
    --key $KEY \
    --maximum-parallel-test-runs $MAX_PARALLEL \
    ${PIPELINE_STAGE:+ --pipeline-stage "$PIPELINE_STAGE"} \
    ${VAR_ARGS:+ "${VAR_ARGS[@]}"}
fi
