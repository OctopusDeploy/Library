targetVersion=$(get_octopusvariable "TargetVersion")
exact=$(get_octopusvariable "Exact")

# required arguments checking
if [[ ! $targetVersion ]] || [[ ! $exact ]] 
then
    echo "[ERROR]: Missing required argument. Exit!"
    exit 1;
fi

dotNetCorePath=/usr/share/dotnet/shared/Microsoft.NETCore.App
dotNetCoreVersions=()
if [ -d "$dotNetCorePath" ]; then
	cd $dotNetCorePath
    dotNetCoreVersions=(*/)
fi

matchedVersions=()
for i in ${dotNetCoreVersions[@]}; do
	if [ $exact = true ] || [ $exact = True ]
    then
    	if [[ $i = $targetVersion/ ]]
        then
        	matchedVersions+=(${i%/})
        fi
    else
    	if [[ ! $i < $targetVersion/ ]]
        then
        	matchedVersions+=(${i%/})
        fi
    fi
done

if [ ${#matchedVersions[@]} -eq 0 ]; then
    echo "Can't find .NET Core Runtime $targetVersion installed in the machine."
    exit 1
else
    for i in ${matchedVersions[@]}; do
    	echo "Found .NET Core Runtime $i installed in the machine."
	done
fi