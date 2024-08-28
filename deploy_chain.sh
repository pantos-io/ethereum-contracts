#!/bin/bash

set -e

mkdir -p .foundry/keystores

echo '{"crypto":{"cipher":"aes-128-ctr","cipherparams":{"iv":"5159c4a67ae85ebbbc2ac7411cc965ef"},"ciphertext":"07a8f37ddc742b96688c6612d1d4c0f0e3a3e2902a3544ca9fe8c081aad22786","kdf":"scrypt","kdfparams":{"dklen":32,"n":8192,"p":1,"r":8,"salt":"3ef92b928e55339fb020a68358be76f7f186bdf40978a353e5f7c7e244936ac0"},"mac":"aa6a17a67b132a3f1babd4a0b02bfaa28ee4810c43b59a31780b921c8c4ac0b4"},"id":"d27236b7-d5c7-441e-aa72-1178bf76eb25","version":3}' > .foundry/keystores/local_deployer

MNEMONIC="test test test test test test test test test test test junk"

declare -A chains
chains=(
    ["ETHEREUM"]=31337
    ["BNB_CHAIN"]=31338
    ["AVALANCHE"]=31339
    ["POLYGON"]=31340
    ["CRONOS"]=31341
    ["FANTOM"]=31342
    ["CELO"]=31343
)

# Define ports for each chain
declare -A ports
ports=(
    ["ETHEREUM"]=8545
    ["BNB_CHAIN"]=8546
    ["AVALANCHE"]=8547
    ["POLYGON"]=8548
    ["CRONOS"]=8549
    ["FANTOM"]=8550
    ["CELO"]=8551
)

declare -A anvil_pids

ROOT_DIR=$(pwd)

rm -rf $ROOT_DIR/*.json
DATA_DIR="$ROOT_DIR/data-static"

mkdir -p $DATA_DIR

deploy_for_chain() {
    local chain=$1
    local chain_id=$2
    local port=$3
    local chain_dir="$DATA_DIR/$chain"

    mkdir -p $chain_dir
    cd $chain_dir

    echo ${MNEMONIC} > $chain_dir/mnemonic.txt

    cp -f ~/.foundry/keystores/local_deployer $chain_dir/keystore
    
    echo '{"deployer": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","medium_critical_ops":"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","pauser": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","super_critical_ops": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}' > $ROOT_DIR/$chain-ROLES.json

    echo "Starting deployment for $chain (Chain ID: $chain_id, Port: $port)"

    # Start anvil in the background
    anvil --port $port --chain-id $chain_id --state-interval 1 --dump-state "$ROOT_DIR/anvil-state-$chain.json" --config-out accounts --mnemonic "${MNEMONIC}" &
    anvil_pids[$chain]=$!

    # Wait for anvil to be available
    while ! nc -z 127.0.0.1 $port; do
        echo "Waiting for anvil to be available for $chain on port $port"
        sleep 1
    done

    forge script "$ROOT_DIR/script/DeployContracts.s.sol" --account local_deployer --chain-id $chain_id \
        --password '' --rpc-url http://127.0.0.1:$port \
        --sig "deploy(uint256,uint256)" 100000000000000000 100000000000000000 --broadcast -vvv

    forge script "$ROOT_DIR/script/DeployContracts.s.sol" --account local_deployer --chain-id $chain_id \
        --password '' --rpc-url http://127.0.0.1:$port \
         --sig "roleActions(uint256,address,address[],bool)" 0 0x88CE2c1d82328f84Dd197f63482A3B68E18cD707 \
        [] false --broadcast -vvv

    jq --arg chain "$chain" -r 'to_entries | map({key: (if .key == "hub_proxy" then "hub" elif .key == "pan" then "pan_token" else .key end), value: .value}) | map("\($chain|ascii_upcase)_\(.key|ascii_upcase)=\(.value|tostring)") | .[]' "$ROOT_DIR/$chain.json" > "$chain_dir/$chain.env"
    cat "$chain_dir/$chain.env" > "$chain_dir/all.env"
    cp "$ROOT_DIR/$chain.json" "$chain_dir/$chain.json"
    cp "$ROOT_DIR/$chain-ROLES.json" "$chain_dir/$chain-ROLES.json"

    echo "Anvil started for $chain..."
}

register_tokens() {
    local chain=$1
    local chain_id=$2
    local port=$3
    local chain_dir="$DATA_DIR/$chain"

    echo "Registering external tokens for $chain..."

    HASH=$(sha256sum "$ROOT_DIR/anvil-state-$chain.json" | cut -d ' ' -f 1)

    # Run the register external tokens script
    forge script "$ROOT_DIR/script/RegisterExternalTokens.s.sol" --account local_deployer --chain-id $chain_id \
        --password '' --rpc-url http://127.0.0.1:$port  --sig "roleActions(bool)" false \
        --broadcast -vvv

    echo "Waiting for the state to change for $chain..."

    # While the state is the same, keep waiting
    while [ $(sha256sum "$ROOT_DIR/anvil-state-$chain.json" | cut -d ' ' -f 1) = $HASH ]; do
        sleep 1
    done

    cp "$ROOT_DIR/anvil-state-$chain.json" "$chain_dir/anvil-state-$chain.json"

    for contract_folder in /root/broadcast/*; do
        for subfolder in "$contract_folder"/*; do
            if echo "$subfolder" | grep -q "$chain_id"; then
                mkdir -p "$chain_dir/broadcast/$(basename "$contract_folder")"
                cp -r "$subfolder" "$chain_dir/broadcast/$(basename "$contract_folder")"
            fi
        done
    done

    echo "Deployment for $chain completed."
}

kill_anvil_processes() {
    echo "Killing anvil processes..."
    for pid in "${anvil_pids[@]}"; do
        kill $pid
    done
}

trap 'kill_anvil_processes' EXIT

for chain in "${!chains[@]}"; do
    deploy_for_chain "$chain" "${chains[$chain]}" "${ports[$chain]}"
done

for chain in "${!chains[@]}"; do
    register_tokens "$chain" "${chains[$chain]}" "${ports[$chain]}"
done
