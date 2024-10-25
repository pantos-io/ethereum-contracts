# Testing Foundry Scripts with Role Signatures

This guide explains the steps to test Foundry scripts that require role-based signatures for execution. The tests are designed to run against a Docker environment with predeployed Pantos contracts on Ethereum nodes.

## Prerequisites

Ensure you have Docker and Foundry installed on your machine.

## Setup

### Start the Docker Stack

The testing environment requires Ethereum nodes running inside Docker containers. These containers are configured to have the Pantos contracts predeployed. 

To start the stack, run the following command:

```bash
make docker
```

### Confirm Stack Status

After starting the stack, confirm that all containers are running correctly:

```bash
docker ps
```

## Testing

### Running Foundry Scripts with Role Signatures

**Use `execute_role_script` for Role-Based Testing**

The `execute_role_script` utility handles the signing and submission of transactions that require specific role signatures. This script ensures transactions are correctly signed and sent to the running Ethereum nodes in the Docker stack.

Example:

```bash
./execute_role_script.sh SetMinValidatorNodeSignatures.s.sol "roleActions(uint256,address,address)" "3 0x0165878A594ca255338adfa4d48449f69242Eb8F 0x9A676e781A523b5d0C0e43731313A708CB607508" "pauser super_critical_ops" ETHEREUM
```
