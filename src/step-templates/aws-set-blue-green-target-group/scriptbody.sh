#!/bin/bash

RULE=${1:-'#{AWSBlueGreen.AWS.RuleArn | Trim}'}
OFFLINEGROUP=${2:-'#{AWSBlueGreen.AWS.OfflineTargetGroup | Trim}'}
ONLINEGROUP=${3:-'#{AWSBlueGreen.AWS.OnlineTargetGroup | Trim}'}

echoerror() { echo "$@" 1>&2; }

if ! command -v "aws" &> /dev/null; then
  echoerror "You must have the AWS CLI installed for this step."
  exit 1
fi

if [[ -z "${RULE}" ]]; then
  echoerror "Please provide the ARN of the listener rule as the first argument"
  exit 1
fi

if [[ -z "${OFFLINEGROUP}" ]]; then
  echoerror "Please provide the ARN of the offline target group as the second argument"
  exit 1
fi

if [[ -z "${ONLINEGROUP}" ]]; then
  echoerror "Please provide the ARN of the online target group as the third argument"
  exit 1
fi

# https://stackoverflow.com/questions/61074411/modify-aws-alb-traffic-distribution-using-aws-cli
MODIFYRULE=$(aws elbv2 modify-rule \
  --rule-arn "${RULE}" \
  --actions \
    "[{
        \"Type\": \"forward\",
        \"Order\": 1,
        \"ForwardConfig\": {
          \"TargetGroups\": [
              {\"TargetGroupArn\": \"${OFFLINEGROUP}\", \"Weight\": 0 },
              {\"TargetGroupArn\": \"${ONLINEGROUP}\", \"Weight\": 100 }
          ]
        }
     }]")

echo "Updated listener rules for ${RULE} to set weight to 0 for ${OFFLINEGROUP} and 100 for ${ONLINEGROUP}."

write_verbose "${MODIFYRULE}"