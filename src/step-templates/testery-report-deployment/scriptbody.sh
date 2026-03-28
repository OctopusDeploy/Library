set -e

TOKEN=$(get_octopusvariable "TesteryToken")
PROJECT_KEY=$(get_octopusvariable "TesteryProjectKey")
ENVIRONMENT_KEY=$(get_octopusvariable "TesteryEnvironmentKey")
BUILD_ID=$(get_octopusvariable "TesteryBuildId")
OUTPUT=$(get_octopusvariable "TesteryOutput")
GIT_REF=$(get_octopusvariable "TesteryGitCommit?")
GIT_BRANCH=$(get_octopusvariable "TesteryGitBranch?")
GIT_OWNER=$(get_octopusvariable "TesteryGitOwner?")
GIT_PROVIDER=$(get_octopusvariable "TesteryGitProvider?")
WAIT_FOR_RESULTS=$(get_octopusvariable "TesteryWaitForResults?")
FAIL_ON_FAILURE=$(get_octopusvariable "TesteryFailOnFailure?")
SKIP_VSC_UPDATE=$(get_octopusvariable "TesterySkipVCSUpdates?")
STATUS_NAME=$(get_octopusvariable "TesteryStatusName?")

if [ "$GIT_PROVIDER" = "None" ] ; then
    GIT_PROVIDER=
fi

if [ "$WAIT_FOR_RESULTS" = "False" ] ; then
    WAIT_FOR_RESULTS=
fi

if [ "$FAIL_ON_FAILURE" = "False" ] ; then
    FAIL_ON_FAILURE=
fi

if [ "$SKIP_VSC_UPDATE" = "False" ] ; then
    SKIP_VSC_UPDATE=
fi

export PATH="$HOME/.local/bin:$PATH"
pip install --user testery --upgrade

testery create-deploy --token $TOKEN \
  --project-key $PROJECT_KEY \
  --environment-key $ENVIRONMENT_KEY \
  --build-id $BUILD_ID \
  --output $OUTPUT \
  ${GIT_REF:+ --git-ref "$GIT_REF"} \
  ${GIT_BRANCH:+ --git-branch "$GIT_BRANCH"} \
  ${GIT_OWNER:+ --git-owner "$GIT_OWNER"} \
  ${GIT_PROVIDER:+ --git-provider "$GIT_PROVIDER"} \
  ${STATUS_NAME:+ --status-name "$STATUS_NAME"} \
  ${WAIT_FOR_RESULTS:+ --wait-for-results} \
  ${FAIL_ON_FAILURE:+ --fail-on-failure} \
  ${SKIP_VSC_UPDATE:+ --skip-vcs-updates}