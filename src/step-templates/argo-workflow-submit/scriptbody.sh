# Check for Argo
if ! command -v argo -v >/dev/null 2>&1
then
    echo "argo executable could not be found. Please use a target or container including it like octopuslabs/argo-workflow-workertools."
    exit 1
fi

# Grab Variables
export wkf_name=$(get_octopusvariable 'ArgoWorkflowSubmit.Name')
export namespace=$(get_octopusvariable 'ArgoWorkflowSubmit.Namespace')
export parameter_array=$(get_octopusvariable "ArgoWorkflowSubmit.Parameters")
export options=$(get_octopusvariable 'ArgoWorkflowSubmit.Options')

# Check workflowTemplate name has been passed
if [ -z "$wkf_name" ] ; then
  echo "WorkflowTemplate name is required"
  exit 1
fi
# Process optional parameters
parameter_string=""
if [ -n "$parameter_array" ] ; then
  parameter_string=$(echo "$parameter_array" | awk '{printf "-p %s ", $0}' | sed 's/ $//')
  echo "Parameter string: $parameter_string"
else
  echo "No parameters passed"
fi


CMD="argo submit -n $namespace --from workflowtemplate/$wkf_name $parameter_string $options -o name"
echo "Workflow Submit command: $CMD"

NAME=$($CMD)
argo logs --follow $NAME

PHASE=$(argo get $NAME -o json | jq -r '.status.phase')

if [[ "$PHASE" == "Succeeded" ]]; then
  echo "Workflow Succeeded."
  exit 0
elif [[ "$PHASE" == "Failed" ]] || [[ "$PHASE" == "Error" ]]; then
  MESSAGE=$(argo get "$NAME" -o json | jq -r '.status.message')
  echo "Workflow Phase: $PHASE."
  echo "Message: $MESSAGE"
  exit 1
else
  echo "Workflow Phase: $PHASE (still running or unknown)."
  exit 2
fi