APOLLO_KEY=$(get_octopusvariable "ApolloKey")
APOLLO_GRAPH_REF=$(get_octopusvariable "ApolloGraphRef")
SUBGRAPH_NAME=$(get_octopusvariable "ApolloSubgraphName")
SUBGRAPH_URL=$(get_octopusvariable "ApolloSubgraphUrl")
SCHEMA=$(get_octopusvariable "ApolloSchema")
ver=$(get_octopusvariable "ApolloRoverVersion")

[ -z "$ver" ] || [ "$ver" == "latest" ] && ROVER_VERSION="latest" || ROVER_VERSION="v$ver"

missing_params=()

[ -z "$APOLLO_KEY" ] && missing_params+=("ApolloKey")
[ -z "$APOLLO_GRAPH_REF" ] && missing_params+=("ApolloGraphRef")
[ -z "$SUBGRAPH_NAME" ] && missing_params+=("SubgraphName")
[ -z "$SUBGRAPH_URL" ] && missing_params+=("SubgraphUrl")
[ -z "$SCHEMA" ] && missing_params+=("Schema")

if [ -n "$missing_params" ]; then
  >&2 echo "Missing parameters: ${missing_params[@]}"
  exit 1
fi

curl -sSL https://rover.apollo.dev/nix/$ROVER_VERSION -o installer

if [ "$(head -n1 installer)" != "#!/bin/bash" ]; then
  >&2 echo "There was a problem fetching $ROVER_VERSION of Rover CLI:"
  >&2 cat installer
  rm installer
  exit 1
fi

sh installer --force 2>&1
rm installer

APOLLO_KEY=$APOLLO_KEY ~/.rover/bin/rover subgraph publish $APOLLO_GRAPH_REF \
  --name $SUBGRAPH_NAME \
  --routing-url $SUBGRAPH_URL \
  --schema $SCHEMA \
  2>&1
