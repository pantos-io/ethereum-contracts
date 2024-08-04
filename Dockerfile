#syntax=docker/dockerfile:1.7.0-labs
FROM --platform=linux/amd64 ghcr.io/foundry-rs/foundry:latest AS build

RUN apk add bash

WORKDIR /app

COPY . .

RUN git config --global --add safe.directory /app

RUN git submodule update --init --recursive

RUN forge build

FROM --platform=linux/amd64 ghcr.io/foundry-rs/foundry:latest AS deployed-contracts

RUN apk add --no-cache jq

WORKDIR /root

COPY --exclude=/app/.git* --from=build /app .

RUN mkdir -p .foundry/keystores && echo '{"crypto":{"cipher":"aes-128-ctr","cipherparams":{"iv":"5159c4a67ae85ebbbc2ac7411cc965ef"},"ciphertext":"07a8f37ddc742b96688c6612d1d4c0f0e3a3e2902a3544ca9fe8c081aad22786","kdf":"scrypt","kdfparams":{"dklen":32,"n":8192,"p":1,"r":8,"salt":"3ef92b928e55339fb020a68358be76f7f186bdf40978a353e5f7c7e244936ac0"},"mac":"aa6a17a67b132a3f1babd4a0b02bfaa28ee4810c43b59a31780b921c8c4ac0b4"},"id":"d27236b7-d5c7-441e-aa72-1178bf76eb25","version":3}' > .foundry/keystores/local_deployer

ARG MNEMONIC="test test test test test test test test test test test junk"

RUN echo ${MNEMONIC} > mnemonic.txt

RUN anvil --port 8545 --chain-id 31337 --state-interval 1 --dump-state anvil-state.json --config-out accounts --mnemonic "${MNEMONIC}" & \
    while ! nc -z 127.0.0.1 8545; do echo 'Waiting for anvil to be available'; sleep 1; done && \
    forge script ./script/DeployContracts.s.sol --account local_deployer \
    --password '' --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url local-8545 \
    --sig "run(address,uint256,uint256,uint256,address[])" 0x88CE2c1d82328f84Dd197f63482A3B68E18cD707 \
    100000000000000000 100000000000000000 0 [] --broadcast && \
    # Convert the Ethereum json to an env file and copy it over
    for chain in ETHEREUM BNB_CHAIN AVALANCHE POLYGON CRONOS FANTOM CELO; do \
    file="$chain.json"; \
    if [ $chain = "BNB_CHAIN" ]; then chain="BNB"; fi; \
    jq --arg chain "$chain" -r 'to_entries | map({key: (if .key == "hub_proxy" then "hub" elif .key == "pan" then "pan_token" else .key end), value: .value}) | map("\($chain|ascii_upcase)_\(.key|ascii_upcase)=\(.value|tostring)") | .[]' ETHEREUM.json > "$chain.env"; \
    cat "$chain.env" >> all.env; \
    if [ ! -f $file ]; then cp -f ETHEREUM.json $file; fi \
    done; \
    echo "Anvil started, running deployment script..." && \
    # Fetch the hash of the file here
    HASH=$(sha256sum anvil-state.json | cut -d ' ' -f 1) && \
    forge script ./script/RegisterExternalTokens.s.sol --account local_deployer \
    --password '' --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
    --rpc-url local-8545 --sig "run()" --broadcast && \
    echo "Waiting for the state to change..." && \
    # While the state is the same, keep waiting
    while [ $(sha256sum anvil-state.json | cut -d ' ' -f 1) = $HASH ]; do sleep 1; done

ENTRYPOINT ["anvil", "--load-state", "anvil-state.json", "--chain-id"]
FROM --platform=linux/amd64 ghcr.io/foundry-rs/foundry:latest AS blockchain-node

COPY --from=deployed-contracts /root/anvil-state.json anvil-state.json
COPY --from=deployed-contracts /root/.foundry/keystores/local_deployer /data-static/keystore
COPY --from=deployed-contracts /root/*.json /data-static/
COPY --from=deployed-contracts /root/*.env /data-static/
COPY --from=deployed-contracts /root/mnemonic.txt /data-static/
COPY --from=deployed-contracts /root/accounts /data-static/
COPY ./entrypoint.sh entrypoint.sh

ENTRYPOINT [ "./entrypoint.sh" ]
