<img src="https://raw.githubusercontent.com/pantos-io/ethereum-contracts/img/pantos-logo-full.svg" alt="Pantos logo" align="right" width="120" />

[![CI](https://github.com/pantos-io/ethereum-contracts/actions/workflows/ci.yaml/badge.svg)](https://github.com/pantos-io/ethereum-contracts/actions/workflows/ci.yaml) 

# Pantos on-chain components for Ethereum and compatible blockchains

This repository contains the Pantos smart contracts for Ethereum-compatible
blockchains.

## Install Foundry 
```shell
$ curl -L https://foundry.paradigm.xyz | bash
$ foundryup
```

## Usage

### Install dependencies

```shell
$ forge install
$ npm install
```

### Build

```shell
$ forge build
```

### Format

```shell
$ make format
```

### Lint

```shell
$ make lint
```

### Test

```shell
$ make test
```

### Coverage

```shell
$ make coverage
```

### Gas Snapshots

```shell
$ forge snapshot
```

### ABIs

```shell
$ make abis
```

### Contract documentation

```shell
$ make docs
```

### ABI documentation

```shell
$ make docs-abis
```

### Contract control flow and inheritance graphs

```shell
$ make docs-graph
$ make docs-inheritance
```

### Docker

**IMPORTANT**: This setup is meant for Docker Desktop. While you may be able to get the same configuration with a locally installed docker engine, we don't actively support this because of the variation amongst distributions.

This setup has been tested with Docker Desktop 2.29.2.

You can run local blockchain nodes using `make docker`. This will start two nodes in ports `8545` and `8546` (called eth and bnb respectively) with the contracts deployed on the same addresses.

This will also create two docker volumes, `eth-data` and `bnb-data`, containing the list of deployed addresses (both in json and .env formats) alongside with the keystore and accounts used. You can access these by using either a docker GUI or by mounting it into a container like this `docker run --rm -v bnb-data:/volume alpine ls /volume`

If using this project alongside the service or validator node projects one can run the full stack by first starting the blockchain nodes with `make docker` and, after these are running, doing the same in the other projects. They will automatically pick up the data exposed by this project.

#### Local development with Docker

You can do local development with Docker by enabling dev mode (Docker watch mode). To do so, set the environment variable `DEV_MODE` to true, like this:

`DEV_MODE=true make docker`

#### Multiple local deployments

We support multiple local deployments, for example for testing purposes, you can run the stacks like this:

`make docker INSTANCE_COUNT=<number of instances>`

To remove all the stacks, run the following:

`make docker-remove`

Please note that this mode uses an incremental amount of resources and that Docker Desktop doesn't fully support displaying it, but it should be good enough to test multi-sig locally.

### Deploy & Operations

Please see ```scripts/README.md```

## Contributions

Check our [code of conduct](CODE_OF_CONDUCT.md)
