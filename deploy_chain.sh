#!/bin/bash

set -e

mkdir -p .foundry/keystores

MNEMONIC="test test test test test test test test test test test junk"

GAS_PAYER_PRIVATE_KEY=$(cast wallet private-key --mnemonic "$MNEMONIC" --mnemonic-index 0) # 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
PAUSER_PRIVATE_KEY=$(cast wallet private-key --mnemonic "$MNEMONIC" --mnemonic-index 100) # 0x8C3229EC621644789d7F61FAa82c6d0E5F97d43D
DEPLOYER_PRIVATE_KEY=$(cast wallet private-key --mnemonic "$MNEMONIC" --mnemonic-index 101) # 0x9586A4833970847aef259aD5BFB7aa8901DDf746
MEDIUM_CRITICAL_OPS_PRIVATE_KEY=$(cast wallet private-key --mnemonic "$MNEMONIC" --mnemonic-index 102) # 0x0e9971c0005D91336c1441b8F03c1C4fe5FB4584
SUPER_CRITICAL_OPS_PRIVATE_KEY=$(cast wallet private-key --mnemonic "$MNEMONIC" --mnemonic-index 103) # 0xC4c81D5C1851702d27d602aA8ff830A7689F17cc

cast wallet import --unsafe-password '' --private-key "$GAS_PAYER_PRIVATE_KEY" gas_payer
cast wallet import --unsafe-password '' --private-key "$PAUSER_PRIVATE_KEY" pauser
cast wallet import --unsafe-password '' --private-key "$DEPLOYER_PRIVATE_KEY" deployer
cast wallet import --unsafe-password '' --private-key "$MEDIUM_CRITICAL_OPS_PRIVATE_KEY" medium_critical_ops
cast wallet import --unsafe-password '' --private-key "$SUPER_CRITICAL_OPS_PRIVATE_KEY" super_critical_ops

GAS_PAYER_ADDRESS=$(cast wallet address --account gas_payer --password '')
PAUSER_SIGNER_ADDRESS=$(cast wallet address --account pauser --password '')
DEPLOYER_SIGNER_ADDRESS=$(cast wallet address --account deployer --password '')
MEDIUM_CRITICAL_OPS_SIGNER_ADDRESS=$(cast wallet address --account medium_critical_ops --password '')
SUPER_CRITICAL_OPS_SIGNER_ADDRESS=$(cast wallet address --account super_critical_ops --password '')

declare -A chains
chains=(
    ["ETHEREUM"]=31337
    ["BNB_CHAIN"]=31338
    ["AVALANCHE"]=31339
    ["POLYGON"]=31340
    ["CRONOS"]=31341
    # Renamed from "FANTOM" to "SONIC" on 2024-10-16 due to network renaming
    ["SONIC"]=31342
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
    # Renamed from "FANTOM" to "SONIC" on 2024-10-16 due to network renaming
    ["SONIC"]=8550
    ["CELO"]=8551
)

declare -A anvil_pids

ROOT_DIR=$(pwd)

rm -rf $ROOT_DIR/*.json
DATA_DIR="$ROOT_DIR/data-static"

mkdir -p $DATA_DIR

# Sign the safe transactions with the given signers generated 
# using the given script name, function name, chain, and chain_id.
# It picks the latest run of the script/chain-id
sign_safe_transactions() {
    local args=("$@")
    local script_name="${args[0]}"
    local function_name="${args[1]}"
    local chain="${args[2]}"
    local chain_id="${args[3]}"

    python3 "$ROOT_DIR/safe-ledger/cli/safe-ledger.py" extend -i \
        "$ROOT_DIR/broadcast/$script_name.s.sol/$chain_id/dry-run/$function_name-latest.json" \
        -s "$ROOT_DIR/$chain-SAFE.json" -o "$ROOT_DIR/safe-transactions-$chain.json"

    for (( i=4; i<${#args[@]}; i++ )); do
        python3 "$ROOT_DIR/safe-ledger/cli/sign_with_cast_wallet.py" "${args[$i]}" \
            "$ROOT_DIR/safe-transactions-$chain.json"
    done

    python3 "$ROOT_DIR/safe-ledger/cli/safe-ledger.py" collate \
        -i "$ROOT_DIR/safe-transactions-$chain.json" \
        -o full_output.json -f "$ROOT_DIR"/"$chain"_flat_output.json
}

deploy_for_chain() {
    local chain=$1
    local chain_id=$2
    local port=$3
    local chain_dir="$DATA_DIR/$chain"

    mkdir -p $chain_dir
    cd $chain_dir

    echo ${MNEMONIC} > $chain_dir/mnemonic.txt

    cp -f ~/.foundry/keystores/gas_payer $chain_dir/keystore
    cp -f ~/.foundry/keystores/pauser $chain_dir/pauser
    cp -f ~/.foundry/keystores/deployer $chain_dir/deployer
    cp -f ~/.foundry/keystores/medium_critical_ops $chain_dir/medium_critical_ops
    cp -f ~/.foundry/keystores/super_critical_ops $chain_dir/super_critical_ops
    
    echo "Starting deployment for $chain (Chain ID: $chain_id, Port: $port)"

    # Start anvil in the background
    anvil --port $port --chain-id $chain_id --state-interval 1 --dump-state "$ROOT_DIR/anvil-state-$chain.json" --config-out accounts --mnemonic "${MNEMONIC}" &
    anvil_pids[$chain]=$!

    # Wait for anvil to be available
    while ! nc -z 127.0.0.1 $port; do
        echo "Waiting for anvil to be available for $chain on port $port"
        sleep 1
    done

    forge script "$ROOT_DIR/script/DeploySafe.s.sol" --account gas_payer --chain-id $chain_id \
        --password '' --rpc-url http://127.0.0.1:$port \
        --sig "deploySafes(address[],uint256,address[],uint256,address[],uint256,address[],uint256)" \
        ["$PAUSER_SIGNER_ADDRESS"] 1 ["$DEPLOYER_SIGNER_ADDRESS"] 1 ["$MEDIUM_CRITICAL_OPS_SIGNER_ADDRESS"] 1 \
        ["$SUPER_CRITICAL_OPS_SIGNER_ADDRESS"] 1 --broadcast -vvv

    forge script "$ROOT_DIR/script/DeployContracts.s.sol" --account gas_payer --chain-id $chain_id \
        --password '' --rpc-url http://127.0.0.1:$port \
        --sig "deploy(uint256,uint256)" 10000000000000000 10000000000000000 --broadcast -vvv

    forge script "$ROOT_DIR/script/DeployContracts.s.sol" --chain-id $chain_id --rpc-url http://127.0.0.1:$port \
        --sig "roleActions(uint256,uint256,uint256,address,address[])" 0 10 1 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 []

    sign_safe_transactions "DeployContracts" "roleActions" "$chain" "$chain_id" "deployer" "super_critical_ops"

    forge script "$ROOT_DIR/script/SubmitSafeTxs.s.sol" --account gas_payer --chain-id $chain_id \
        --password '' --rpc-url http://127.0.0.1:$port --sig "run()" --broadcast -vvv

    # send the PAN tokens from the super critical role safe to the gas payer
    calldata=$(cast calldata "transfer(address,uint256)" $GAS_PAYER_ADDRESS 10000000000000000)
    super_critical_ops_safe_address=$(jq -r '.super_critical_ops' "$ROOT_DIR/$chain-ROLES.json")
    pan_token_contract_address=$(jq -r '.pan' "$ROOT_DIR/$chain.json")
    nonce=$(cast call $super_critical_ops_safe_address "nonce()(uint256)" --rpc-url http://127.0.0.1:$port)
    tx_hash=$(cast call $super_critical_ops_safe_address \
        "getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256)" \
        $pan_token_contract_address 0 $calldata 0 0 0 0 0x0000000000000000000000000000000000000000 \
        0x0000000000000000000000000000000000000000 $nonce --rpc-url http://127.0.0.1:$port)
    cast send --account gas_payer --password '' $SUPER_CRITICAL_OPS_SIGNER_ADDRESS --value 1ether \
        --rpc-url http://127.0.0.1:$port --gas-price 10gwei --confirmations 1
    cast send --account super_critical_ops --password '' $super_critical_ops_safe_address \
        "approveHash(bytes32)" $tx_hash --rpc-url http://127.0.0.1:$port --gas-price 10gwei --confirmations 1
    cast send --account gas_payer --password '' $super_critical_ops_safe_address \
        "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)" \
        $pan_token_contract_address 0 $calldata 0 0 0 0 0x0000000000000000000000000000000000000000 \
        0x0000000000000000000000000000000000000000 \
        "0x000000000000000000000000${SUPER_CRITICAL_OPS_SIGNER_ADDRESS:2}000000000000000000000000000000000000000000000000000000000000000001" \
        --rpc-url http://127.0.0.1:$port --gas-price 10gwei --confirmations 1

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
    forge script "$ROOT_DIR/script/RegisterExternalTokens.s.sol" --chain-id $chain_id \
        --rpc-url http://127.0.0.1:$port  --sig "roleActions()"

    sign_safe_transactions "RegisterExternalTokens" "roleActions" "$chain" "$chain_id" "super_critical_ops"

    forge script "$ROOT_DIR/script/SubmitSafeTxs.s.sol" --account gas_payer --chain-id $chain_id \
        --password '' --rpc-url http://127.0.0.1:$port --sig "run()" --broadcast -vvv

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
    cp "$ROOT_DIR/$chain-SAFE.json" "$chain_dir/$chain-SAFE.json"

    echo "Deployment for $chain completed."
}

kill_anvil_processes() {
    echo "Killing anvil processes..."
    for pid in "${anvil_pids[@]}"; do
        kill $pid
    done
}

trap 'kill_anvil_processes' EXIT

source "$ROOT_DIR/safe-ledger/venv/bin/activate"

for chain in "${!chains[@]}"; do
    deploy_for_chain "$chain" "${chains[$chain]}" "${ports[$chain]}"
done

for chain in "${!chains[@]}"; do
    register_tokens "$chain" "${chains[$chain]}" "${ports[$chain]}"
done
