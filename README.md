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

### Deploy & Operations

Please see ```scripts/README.md```

## Contributions

Check our [code of conduct](CODE_OF_CONDUCT.md)