#!/bin/bash

INACTIVECOLOR=${1:-'#{AWSBlueGreen.InactiveColor | Trim}'}
GREENASG=${2:-'#{AWSBlueGreen.AWS.GreenASG | Trim}'}
BLUEASG=${3:-'#{AWSBlueGreen.AWS.BlueASG | Trim}'}

echoerror() { echo "$@" 1>&2; }

if [[ -z "${INACTIVECOLOR}" ]]
then
  echoerror "Please provide the color of the inactive Auto Scaling group (Green or Blue) as the first argument"
  exit 1
fi

if [[ -z "${GREENASG}" ]]
then
  echoerror "Please provide the name of the Green Auto Scaling group as the second argument"
  exit 1
fi

if [[ -z "${BLUEASG}" ]]
then
  echoerror "Please provide the name of the Blue Auto Scaling group as the third argument"
  exit 1
fi

if [[ "${INACTIVECOLOR^^}" == "GREEN" ]]
then
  set_octopusvariable "ActiveGroup" "${BLUEASG}"
  set_octopusvariable "InactiveGroup" "${GREENASG}"
  echo "Active group is Blue (${BLUEASG}), inactive group is Green (${GREENASG})"
else
  set_octopusvariable "ActiveGroup" "${GREENASG}"
    set_octopusvariable "InactiveGroup" "${BLUEASG}"
    echo "Active group is Green (${GREENASG}), inactive group is Blue (${BLUEASG})"
fi