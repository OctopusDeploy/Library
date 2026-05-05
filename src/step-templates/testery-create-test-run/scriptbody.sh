set -e

TOKEN=$(get_octopusvariable "TesteryToken")
PROJECT_KEY=$(get_octopusvariable "TesteryProjectKey")
ENVIRONMENT_KEY=$(get_octopusvariable "TesteryEnvironmentKey")
GIT_REF=$(get_octopusvariable "TesteryGitRef?")
GIT_BRANCH=$(get_octopusvariable "TesteryGitBranch?")
TEST_NAME=$(get_octopusvariable "TesteryTestName?")
WAIT_FOR_RESULTS=$(get_octopusvariable "TesteryWaitForResults?")
TEST_SUITE=$(get_octopusvariable "TesteryTestSuite?")
LATEST_DEPLOY=$(get_octopusvariable "TesteryLatestDeploy?")
INCLUDED_TAGS=$(get_octopusvariable "TesteryIncludedTags?")
EXCLUDED_TAGS=$(get_octopusvariable "TesteryExcludedTags?")
COPIES=$(get_octopusvariable "TesteryCopies?")
BUILD_ID=$(get_octopusvariable "TesteryBuildId?")
OUTPUT=$(get_octopusvariable "TesteryOutput")
VARIABLES=$(get_octopusvariable "TesteryVariables?")
INCLUDE_ALL_TAGS=$(get_octopusvariable "TesteryIncludeAllTags?")
PARALLELIZATION=$(get_octopusvariable "TesteryParallelizationType?")
FAIL_ON_FAILURE=$(get_octopusvariable "TesteryFailOnFailure?")
RUN_TIMEOUT=$(get_octopusvariable "TesteryRunTimeout?")
TEST_TIMEOUT=$(get_octopusvariable "TesteryTestTimeout?")
RUNNER_COUNT=$(get_octopusvariable "TesteryRunnerCount?")
TEST_FILTER=$(get_octopusvariable "TesteryTestFilterRegex?")
STATUS_NAME=$(get_octopusvariable "TesteryStatusName?")
PLAYWRIGHT_PROJECT=$(get_octopusvariable "TesteryPlaywrightProject?")
SKIP_VSC_UPDATE=$(get_octopusvariable "TesterySkipVCSUpdates?")
DEPLOY_ID=$(get_octopusvariable "TesteryDeployId?")
APPLY_TEST_SELECT=$(get_octopusvariable "TesteryApplyTestSelectionRules?")

if [ "$WAIT_FOR_RESULTS" = "False" ] ; then
    WAIT_FOR_RESULTS=
fi

if [ "$PARALLELIZATION" = "default" ] ; then
    PARALLELIZATION=
fi

if [ "$FAIL_ON_FAILURE" = "False" ] ; then
    FAIL_ON_FAILURE=
fi

if [ "$APPLY_TEST_SELECT" = "False" ] ; then
    APPLY_TEST_SELECT=
fi

if [ "$SKIP_VSC_UPDATE" = "False" ] ; then
    SKIP_VSC_UPDATE=
fi

if [ "$INCLUDE_ALL_TAGS" = "False" ] ; then
    INCLUDE_ALL_TAGS=
fi

if [ "$LATEST_DEPLOY" = "False" ] ; then
    LATEST_DEPLOY=
fi

if [[ -n "$INCLUDED_TAGS" ]]; then
  INCLUDED_TAGS=$(echo "$INCLUDED_TAGS" | tr '\n' ',' | sed 's/,$//')
fi

if [[ -n "$EXCLUDED_TAGS" ]]; then
  EXCLUDED_TAGS=$(echo "$EXCLUDED_TAGS" | tr '\n' ',' | sed 's/,$//')
fi

VAR_ARGS=()
if [[ -n "$VARIABLES" ]]; then
  mapfile -t VAR_LINES <<< "$VARIABLES"
  for line in "${VAR_LINES[@]}"; do
    [[ -z "$line" ]] && continue
    VAR_ARGS+=("--variable" "$line")
  done
fi

export PATH="$HOME/.local/bin:$PATH"
pip install --user testery --upgrade


testery create-test-run --token $TOKEN \
  --project-key $PROJECT_KEY \
  --environment-key $ENVIRONMENT_KEY \
  --output $OUTPUT \
  ${GIT_REF:+ --git-ref "$GIT_REF"} \
  ${GIT_BRANCH:+ --git-branch "$GIT_BRANCH"} \
  ${TEST_NAME:+ --test-name "$TEST_NAME"} \
  ${WAIT_FOR_RESULTS:+ --wait-for-results} \
  ${TEST_SUITE:+ --test-suite "$TEST_SUITE"} \
  ${LATEST_DEPLOY:+ --latest-deploy } \
  ${COPIES:+ --copies "$COPIES"} \
  ${BUILD_ID:+ --build-id "$BUILD_ID"} \
  ${FAIL_ON_FAILURE:+ --fail-on-failure} \
  ${INCLUDE_ALL_TAGS:+ --include-all-tags} \
  ${PARALLELIZATION:+ "${PARALLELIZATION}"} \
  ${RUN_TIMEOUT:+ --timeout-minutes "$RUN_TIMEOUT"} \
  ${TEST_TIMEOUT:+ --test-timeout-seconds "$TEST_TIMEOUT"} \
  ${RUNNER_COUNT:+ --runner-count "$RUNNER_COUNT"} \
  ${VAR_ARGS:+ "${VAR_ARGS[@]}"} \
  ${TEST_FILTER:+ --test-filter-regex "$TEST_FILTER"} \
  ${STATUS_NAME:+ --status-name "$STATUS_NAME"} \
  ${PLAYWRIGHT_PROJECT:+ --playwright-project "$PLAYWRIGHT_PROJECT"} \
  ${SKIP_VSC_UPDATE:+ --skip-vcs-updates} \
  ${DEPLOY_ID:+ --deploy-id "$DEPLOY_ID"} \
  ${APPLY_TEST_SELECT:+ --apply-test-selection-rules} \
  ${INCLUDED_TAGS:+ --include-tags "$INCLUDED_TAGS"} \
  ${EXCLUDED_TAGS:+ --exclude-tags "$EXCLUDED_TAGS"}
