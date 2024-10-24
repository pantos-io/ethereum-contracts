#!/usr/bin/env bash

# This script executes a forge script which requires roles to sign the transactions in the context of local development.
#
# It requires 5 arguments to run:
# 1. script_name: The name of the script to be executed.
# 2. function_name: The function within the script to be called.
# 3. function_arguments: The arguments to be passed to the function.
# 4. roles_to_sign: The roles that need to sign the transaction.
# 5. chain_name: The name of the blockchain network (e.g., ETHEREUM, BNB_CHAIN).

# Usage:
# ./execute_role_script.sh <script_name> <function_name> <function_arguments> <roles_to_sign> <chain_name>

# Example:
# ./execute_role_script.sh UpdateFeeFactors.s.sol "roleActions(address,address)" \
#     "0x0165878A594ca255338adfa4d48449f69242Eb8F 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6" \
#     "medium_critical_ops" ETHEREUM

# The script performs the following steps:
# 1. Validates the input arguments.
# 2. Sets up the necessary environment variables and paths.
# 3. Checks if the Docker stack is started.
# 4. Imports wallets using predefined mnemonics.
# 5. Activates a Python virtual environment and installs dependencies.
# 6. Executes the specified script using `forge`.
# 7. Extends and signs the transaction using `safe-ledger.py`.
# 8. Collates the signed transactions.
# 9. Submits the transaction using `forge`.
# 10. Cleans up temporary files and moves the final SAFE.json file to the volume directory.

set -e

if [ "$#" -ne 5 ]; then
    echo "Error: Exactly 5 arguments are required."
    exit 1
fi

args=("$@")
script_name="${args[0]}"
function_name="${args[1]}"
function_arguments=("${args[2]}")
roles_to_sign=("${args[3]}")
chain_name="${args[4]}"

declare -A chains_to_port
chains_to_port=(
    ["ETHEREUM"]=8545
    ["BNB_CHAIN"]=8546
)

declare -A chains_to_id
chains_to_id=(
    ["ETHEREUM"]=31337
    ["BNB_CHAIN"]=31338
)

if [[ -z "${chains_to_port[$chain_name]}" ]]; then
    echo "Error: Unsupported chain name '$chain_name'."
    exit 1
else 
    chain_port="${chains_to_port[$chain_name]}"
fi
chain_id="${chains_to_id[$chain_name]}"

rpc_url="localhost:$chain_port"

# Check if the docker stack is started
compose_stacks=$(docker compose ls --filter "name=$stack_name" --format json | jq -r '.[].Name' | awk "/^$stack_name/ {print}"); 
if [[ -z "$compose_stacks" ]]; then
    echo "Error: Docker stack '$stack_name' is not started."
    exit 1
elif [[ "$compose_stacks" == *$'\n'* ]]; then
    compose_stack=$(echo "$compose_stacks" | head -n 1)
else 
    compose_stack=$compose_stacks
fi

docker_compose_stack_name=stack-ethereum-contracts
project_dir=".."
script_dir="$project_dir/script"
safe_ledger_dir="$project_dir/safe-ledger"
if [[ "$chain_name" == "ETHEREUM" ]]; then
    volume_dir="../data/$compose_stack/eth"
elif [[ "$chain_name" == "BNB_CHAIN" ]]; then
    volume_dir="../data/$compose_stack/bnb"
fi
broadcast_path="$project_dir/broadcast/$script_name/$chain_id/dry-run/${function_name%%(*}-latest.json"

# Find the script file in the nested path within script_dir
script_path=$(find "$script_dir" -type f -name "$script_name")
submit_safe_tx_script_path="$project_dir"/script/SubmitSafeTxs.s.sol

if [ -z "$script_path" ]; then
    echo "Error: Script '$script_name' not found in '$script_dir'."
    exit 1
fi

mnemonic="test test test test test test test test test test test junk"

gas_payer_private_key=$(cast wallet private-key --mnemonic "$mnemonic" --mnemonic-index 0) # 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
pauser_private_key=$(cast wallet private-key --mnemonic "$mnemonic" --mnemonic-index 100) # 0x8C3229EC621644789d7F61FAa82c6d0E5F97d43D
deployer_private_key=$(cast wallet private-key --mnemonic "$mnemonic" --mnemonic-index 101) # 0x9586A4833970847aef259aD5BFB7aa8901DDf746
medium_critical_ops_private_key=$(cast wallet private-key --mnemonic "$mnemonic" --mnemonic-index 102) # 0x0e9971c0005D91336c1441b8F03c1C4fe5FB4584
super_critical_ops_private_key=$(cast wallet private-key --mnemonic "$mnemonic" --mnemonic-index 103) # 0xC4c81D5C1851702d27d602aA8ff830A7689F17cc

# add wallets to cast wallet
set +e
cast wallet import --unsafe-password '' --private-key "$gas_payer_private_key" gas_payer 2>/dev/null
cast wallet import --unsafe-password '' --private-key "$pauser_private_key" pauser 2>/dev/null
cast wallet import --unsafe-password '' --private-key "$deployer_private_key" deployer 2>/dev/null
cast wallet import --unsafe-password '' --private-key "$medium_critical_ops_private_key" medium_critical_ops 2>/dev/null
cast wallet import --unsafe-password '' --private-key "$super_critical_ops_private_key" super_critical_ops 2>/dev/null
set -e

if [ ! -d "$safe_ledger_dir/.venv" ]; then
    python3 -m venv "$safe_ledger_dir/.venv"
    source "$safe_ledger_dir/.venv/bin/activate"
    pip install -r "$safe_ledger_dir/requirements.txt"
else 
    source "$safe_ledger_dir/.venv/bin/activate"
fi

forge script "$script_path" -vvv --rpc-url "$rpc_url" --sig $function_name $function_arguments

python3 "$safe_ledger_dir/cli/safe-ledger.py" extend -i $broadcast_path \
    -s "$volume_dir/$chain_name-SAFE.json" -o "./safe-transactions.json"

for (( i=0; i<${#roles_to_sign[@]}; i++ )); do
    python3 "$safe_ledger_dir/cli/sign_with_cast_wallet.py" "${roles_to_sign[$i]}" \
        "./safe-transactions.json"
done

python3 "$safe_ledger_dir/cli/safe-ledger.py" collate \
    -i "./safe-transactions.json" \
    -o full_output.json -f "$project_dir"/"$chain_name"_flat_output.json

forge script "$submit_safe_tx_script_path" --account gas_payer --password '' -vvv \
    --rpc-url "$rpc_url" --sig "run()" --with-gas-price 10gwei --broadcast 

rm ./full_output.json
rm ./safe-transactions.json
rm ../"$chain_name"_flat_output.json
mv ../"$chain_name"-SAFE.json "$volume_dir/"$chain_name"-SAFE.json"
