"""Script to sign gnosis safe-ready transactions using Foundry keystores.

This script lists the accounts available in the Foundry keystore and checks 
if the specified account is present. If the account is found, it retrieves 
the account address and reads the transactions from the provided JSON file.
For each transaction, it checks if the account is required to sign and, 
if so, signs the transaction and updates the JSON file with the signature.

The script expects the JSON file to have the following structure:
{
    "transactions": [
        {
            "safeTx": <transaction_data>,
            "signatures": [
                {
                    "signer": <account_address>,
                    "signature": <signature>
                },
                ...
        },
        ...
}

The script will update the "signature" field for the required signers with the generated signature.

Usage
-----
    python3 sign_with_keystore.py <account_name> <safe_transactions_file_path>

Arguments
---------
    <account_name> : str
        The name of the Foundry account to use for signing transactions.
    <safe_transactions_file_path> : str
        The path to the JSON file containing the transactions to be signed.

"""

import json
import subprocess
import sys
import typing


def sign_safe_tx(safe_tx_data: dict[str, typing.Any],
                 account_name: str) -> str | None:
    safe_tx_hex = json.dumps(safe_tx_data)
    cmd = [
        'cast', 'wallet', 'sign', '--account', account_name, '--password', '',
        '--data', safe_tx_hex
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error signing transaction: {result.stderr}")
        return None
    return result.stdout.strip()


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: python sign_with_keystore.py <account_name> ",
              "<safe_transactions_file_path>")
        sys.exit(1)
    account_name = sys.argv[1]
    safe_transactions_file_path = sys.argv[2]
    cmd = ['cast', 'wallet', 'list']
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error listing accounts: {result.stderr}")
        sys.exit(1)
    accounts = result.stdout.splitlines()
    account_address = None
    for account in accounts:
        if account_name in account:
            cmd = [
                'cast', 'wallet', 'address', '--account', account_name,
                '--password', ''
            ]
            account_address = subprocess.run(cmd,
                                             capture_output=True,
                                             text=True).stdout.strip()
            break
    if not account_address:
        print(f"Account {account_name} is not available in foundry keystores")
        sys.exit(1)

    with open(safe_transactions_file_path, 'r') as file:
        transactions = json.load(file)

    for transaction in transactions['transactions']:
        safe_tx_data = transaction['safeTx']
        signatures_needed = transaction['signatures']
        for signature_needed in signatures_needed:
            if signature_needed['signer'] == account_address:
                signature = sign_safe_tx(safe_tx_data, account_name)
                signature_needed['signature'] = signature

    with open(safe_transactions_file_path, 'w') as outfile:
        json.dump(transactions, outfile, indent=4)


main()
