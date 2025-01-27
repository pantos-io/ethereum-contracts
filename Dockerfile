#syntax=docker/dockerfile:1.7.0-labs
# SPDX-License-Identifier: GPL-3.0-only
FROM ghcr.io/foundry-rs/foundry:latest AS build

RUN apt-get update && apt-get install -y bash git

WORKDIR /app

COPY . .

RUN git config --global --add safe.directory /app

RUN git submodule update --init --recursive

RUN forge build

ENTRYPOINT ["sh", "-c"]
CMD ["echo 'Ready'"]

FROM ghcr.io/foundry-rs/foundry:latest AS deployed-contracts

RUN apt-get update && apt-get install -y jq bash python3-dev build-essential python3-venv netcat

WORKDIR /root

COPY --exclude=/app/.git* --from=build /app .

RUN python3 -m venv safe-ledger/venv && \
    . safe-ledger/venv/bin/activate && \
    pip install -r safe-ledger/requirements.txt

RUN ./deploy_chain.sh

ENTRYPOINT ["anvil"]
CMD ["--load-state", "anvil-state-ETHEREUM.json", "--chain-id", "31337"]

FROM ghcr.io/foundry-rs/foundry:latest AS blockchain-node

COPY --from=deployed-contracts /root/data-static /data-static/
COPY ./entrypoint.sh /root/entrypoint.sh

ENTRYPOINT ["sh", "-c"]
CMD ["/root/entrypoint.sh"]
