#!/bin/sh

# If the first parameter is provided, use it as CHAIN_ID
if [ -n "$1" ]; then
    CHAIN_ID=$1
    shift
else
    # If CHAIN_ID is not provided and no parameters are passed, use 31337 as default
    CHAIN_ID=${CHAIN_ID:-31337}
fi

echo "Starting Anvil with chain id $CHAIN_ID"
if [ -d /data ]; then
    echo "Data volume detected, copying static files to /data"
else
    mkdir /data
    echo "No data volume detected, get the configuration from /data"
fi
cp -R /data-static/* /data/

# Pass all remaining parameters to anvil
anvil --load-state anvil-state.json --host "0.0.0.0" --config-out /data/accounts --chain-id "${CHAIN_ID}" "$@"
