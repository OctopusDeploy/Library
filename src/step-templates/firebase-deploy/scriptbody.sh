packagePath=$(get_octopusvariable "Octopus.Action.Package[FirebaseDeploy.Package].ExtractedPath")
token=$(get_octopusvariable "FirebaseDeploy.CIToken")
public=$(get_octopusvariable "FirebaseDeploy.Public")
message=$(get_octopusvariable "FirebaseDeploy.Message")
force=$(get_octopusvariable "FirebaseDeploy.Force")
only=$(get_octopusvariable "FirebaseDeploy.Only")
except=$(get_octopusvariable "FirebaseDeploy.Except")
printCommand=$(get_octopusvariable "FirebaseDeploy.PrintCommand")
firebasePath=$(get_octopusvariable "FirebaseDeploy.FirebasePath")

if [ ! -z "$firebasePath" ] ; then
   	PATH=$firebasePath:$PATH
fi

if [ "$force" = "True" ] ; then
    force=true
else
    force=
fi

if [ "$printCommand" = "True" ] ; then
    set -x
fi

cd $packagePath

firebase deploy ${public:+ -p "$public"} ${message:+ -m "$message"} ${force:+ -f} ${only:+ --only "$only"} ${except:+ --except "$except"} --token $token