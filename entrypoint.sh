#!/bin/sh

chains() {
    case "$1" in
        "ETHEREUM") echo 31337 ;;
        "BNB_CHAIN") echo 31338 ;;
        "AVALANCHE") echo 31339 ;;
        "POLYGON") echo 31340 ;;
        "CRONOS") echo 31341 ;;
        "SONIC") echo 31342 ;;
        "CELO") echo 31343 ;;
        *) echo "" ;;
    esac
}

# If the first parameter is provided, use it as CHAIN
if [ -n "$1" ]; then
    # Convert the input to uppercase
    CHAIN=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    shift
elif [ -n "$CHAIN" ]; then
    # If CHAIN is provided as an environment variable, use it
    CHAIN=$(echo "$CHAIN" | tr '[:lower:]' '[:upper:]')
else
    # If CHAIN is not provided, default to ETHEREUM and warn the user
    CHAIN="ETHEREUM"
    echo "Warning: No chain provided. Defaulting to ETHEREUM."
fi

CHAIN_ID=$(chains "$CHAIN")

# Check if the provided chain is valid
if [ -z "$CHAIN_ID" ]; then
    echo "Error: Invalid chain '$CHAIN'. Valid options are: ETHEREUM, BNB_CHAIN, AVALANCHE, POLYGON, CRONOS, SONIC, CELO"
    exit 1
fi

echo "Starting Anvil with chain $CHAIN (Chain ID: $CHAIN_ID)"
for dir in /data /data2; do
  if [ -d "$dir" ]; then
    echo "Data volume detected, copying static files to $dir"
  else
    mkdir -p "$dir"
    echo "No data volume detected, created $dir and copying static files"
  fi
  cp -R /data-static/$CHAIN/* "$dir/"
done

# Pass all remaining parameters to anvil
anvil --load-state "/data/anvil-state-$CHAIN.json" --block-time 4 --host "0.0.0.0" --config-out /data/accounts --chain-id "${CHAIN_ID}" "$@"
