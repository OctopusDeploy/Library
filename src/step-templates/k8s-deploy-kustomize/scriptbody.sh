# kubectl is required
if ! [ -x "$(command -v kubectl)" ]; then
	fail_step 'kubectl command not found'
fi

REFERENCED_PACKAGE_NAME="K8sKustomize.DeploymentConfiguration"
KUSTOMIZE_OVERLAY_PATH=$(get_octopusvariable "K8sKustomize.OverlayPath")

echo "Referenced package name:$REFERENCED_PACKAGE_NAME"
echo "Overlay path: $KUSTOMIZE_OVERLAY_PATH"

PACKAGE_LOCATION=$(get_octopusvariable "Octopus.Action.Package["$REFERENCED_PACKAGE_NAME"].ExtractedPath")
echo "Extracted package location: $PACKAGE_LOCATION"

cd $PACKAGE_LOCATION
kubectl apply -k $KUSTOMIZE_OVERLAY_PATH