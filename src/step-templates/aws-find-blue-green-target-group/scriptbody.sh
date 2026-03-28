#!/bin/bash

LISTENER=${1:-'#{AWSBlueGreen.AWS.ListenerARN | Trim}'}
RULE=${2:-'#{AWSBlueGreen.AWS.RuleArn | Trim}'}
GREENTARGETGROUP=${3:-'#{AWSBlueGreen.AWS.GreenTargetGroup | Trim}'}
BLUETARGETGROUP=${4:-'#{AWSBlueGreen.AWS.BlueTargetGroup | Trim}'}

echoerror() { echo "$@" 1>&2; }

if ! command -v "aws" &> /dev/null; then
  echoerror "You must have the AWS CLI installed for this step. Consider using a Container Image - https://octopus.com/docs/projects/steps/execution-containers-for-workers#how-to-use-execution-containers-for-workers"
  exit 1
fi

if ! command -v "jq" &> /dev/null; then
  echoerror "You must have jq installed for this step. Consider using a Container Image - https://octopus.com/docs/projects/steps/execution-containers-for-workers#how-to-use-execution-containers-for-workers"
  exit 1
fi

# Validate the arguments

if [[ -z "${LISTENER}" ]]; then
  echoerror "Please provide the ARN of the listener as the first argument"
  exit 1
fi

if [[ -z "${RULE}" ]]; then
  echoerror "Please provide the ARN of the listener rule as the second argument"
  exit 1
fi

if [[ -z "${GREENTARGETGROUP}" ]]; then
  echoerror "Please provide the ARN of the green target group as the third argument"
  exit 1
fi

if [[ -z "${BLUETARGETGROUP}" ]]; then
  echoerror "Please provide the ARN of the blue target group as the fourth argument"
  exit 1
fi

# Get the JSON representation of the listener rules

RULES=$(aws elbv2 describe-rules \
  --listener-arn "${LISTENER}" \
  --output json)

write_verbose "${RULES}"

# Find the weight assigned to each of the target groups.

GREENWEIGHT=$(jq -r ".Rules[] | select(.RuleArn == \"${RULE}\") | .Actions[] | select(.Type == \"forward\") | .ForwardConfig | .TargetGroups[] | select(.TargetGroupArn == \"${GREENTARGETGROUP}\") | .Weight" <<< "${RULES}")
BLUEWEIGHT=$(jq -r ".Rules[] | select(.RuleArn == \"${RULE}\") | .Actions[] | select(.Type == \"forward\") | .ForwardConfig | .TargetGroups[] | select(.TargetGroupArn == \"${BLUETARGETGROUP}\") | .Weight" <<< "${RULES}")

# Validation that we found the green and blue target groups.

if [[ -z "${GREENWEIGHT}" ]]; then
  echoerror "Failed to find the target group ${GREENTARGETGROUP} in the listener rule ${RULE}"
  echoerror "Double check that the target group exists and has been associated with the load balancer"
  exit 1
fi

if [[ -z "${BLUEWEIGHT}" ]]; then
  echoerror "Failed to find the target group ${BLUETARGETGROUP} in the listener rule ${RULE}"
  echoerror "Double check that the target group exists and has been associated with the load balancer"
  exit 1
fi

echo "Green weight: ${GREENWEIGHT}"
echo "Blue weight: ${BLUEWEIGHT}"

# Set the output variables identifying which target group is active and which is inactive.
# Note that we assume the target groups are either active or inactive (i.e. all traffic and no traffic).
# Load balancers support more complex routing rules, but we assume a simple blue-green deployment.
# If the green target group has traffic, it is considered active, and the blue target group is considered inactive.
# If the green target group has no traffic, it is considered inactive, and the blue target group is considered active.

if [ "${GREENWEIGHT}" != "0" ]; then
  echo "Green target group is active, blue target group is inactive"
  set_octopusvariable "ActiveGroupArn" "${GREENTARGETGROUP}"
  set_octopusvariable "ActiveGroupColor" "Green"
  set_octopusvariable "InactiveGroupArn" "${BLUETARGETGROUP}"
  set_octopusvariable "InactiveGroupColor" "Blue"
else
  echo "Blue target group is active, green target group is inactive"
  set_octopusvariable "ActiveGroupArn" "${BLUETARGETGROUP}"
  set_octopusvariable "ActiveGroupColor" "Blue"
  set_octopusvariable "InactiveGroupArn" "${GREENTARGETGROUP}"
  set_octopusvariable "InactiveGroupColor" "Green"
fi