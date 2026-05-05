rsyncPath=$(get_octopusvariable "Rsync.Path")
rsyncOptions=$(get_octopusvariable "Rsync.Options")
rsyncSource=$(get_octopusvariable "Rsync.Source")
rsyncDestination=$(get_octopusvariable "Rsync.Destination")
printCommand=$(get_octopusvariable "Rsync.PrintCommand")

if [ ! -z "$rsyncPath" ] ; then
   	PATH=$rsyncPath:$PATH
fi

if [ "$printCommand" = "True" ] ; then
    set -x
fi

rsync ${rsyncOptions:+ $rsyncOptions} ${rsyncSource:+ $rsyncSource} ${rsyncDestination:+ $rsyncDestination}