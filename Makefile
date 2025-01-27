STACK_BASE_NAME=stack-ethereum-contracts
INSTANCE_COUNT ?= 1
DEV_MODE ?= false
SHELL := $(shell which bash) -x

LIB_PATH := lib
OPENZEPPELIN_LIB_PATH := ${LIB_PATH}/openzeppelin-contracts

JSON_PATH := out
HUB_JSON_PATH := ${JSON_PATH}/IPantosHub.sol/IPantosHub.json
FORWARDER_JSON_PATH := ${JSON_PATH}/IPantosForwarder.sol/IPantosForwarder.json
TOKEN_JSON_PATH := ${JSON_PATH}/IPantosToken.sol/IPantosToken.json

ABI_PATH := abis
HUB_ABI_PATH := ${ABI_PATH}/pantos-hub.abi
FORWARDER_ABI_PATH := ${ABI_PATH}/pantos-forwarder.abi
TOKEN_ABI_PATH := ${ABI_PATH}/pantos-token.abi

DOC_PATH := docs
INTERFACE_DOC_PATH := ${DOC_PATH}/src/src/interfaces
REGISTRY_DOC_PATH := ${INTERFACE_DOC_PATH}/IPantosRegistry.sol/interface.IPantosRegistry.md
TRANSFER_DOC_PATH := ${INTERFACE_DOC_PATH}/IPantosTransfer.sol/interface.IPantosTransfer.md
TOKEN_DOC_PATH := ${INTERFACE_DOC_PATH}/IPantosToken.sol/interface.IPantosToken.md
BEP20_DOC_PATH := ${INTERFACE_DOC_PATH}/IBEP20.sol/interface.IBEP20.md

OPENZEPPELIN_DOC_PATH := ${DOC_PATH}/openzeppelin
ERC20_DOC_PATH := ${OPENZEPPELIN_DOC_PATH}/src/contracts/token/ERC20/IERC20.sol/interface.IERC20.md
ERC165_DOC_PATH := ${OPENZEPPELIN_DOC_PATH}/src/contracts/utils/introspection/IERC165.sol/interface.IERC165.md

ABI_DOC_PATH := ${DOC_PATH}/abis
HUB_ABI_DOC_PATH := ${ABI_DOC_PATH}/pantos-hub-abi.md
TOKEN_ABI_DOC_PATH := ${ABI_DOC_PATH}/pantos-token-abi.md

TEMPLATE_PATH := templates
HUB_ABI_DOC_TEMPLATE_PATH := ${TEMPLATE_PATH}/pantos-hub-abi.md
TOKEN_ABI_DOC_TEMPLATE_PATH := ${TEMPLATE_PATH}/pantos-token-abi.md

.PHONY: build
build:
	forge build

.PHONY: clean
clean:
	@forge clean; \
	for path in "${ABI_PATH}" "${DOC_PATH}"; do \
		rm -r -f "$${path}"; \
	done

.PHONY: format
format:
	npx prettier --write --plugin=prettier-plugin-solidity '{src,script,test}/**/*.sol' 

.PHONY: lint
lint:
	npx solhint '{src,script,test}/**/*.sol'

.PHONY: code
code: format lint build test snapshot

.PHONY: test
test:
	forge test -vvv

.PHONY: coverage
coverage:
	forge coverage --ir-minimum

.PHONY: snapshot
snapshot:
	forge snapshot

.PHONY: abis
abis: build
	@set -e; \
	mkdir -p "${ABI_PATH}"; \
	jq '.abi' "${HUB_JSON_PATH}" > "${HUB_ABI_PATH}"; \
	jq '.abi' "${FORWARDER_JSON_PATH}" > "${FORWARDER_ABI_PATH}"; \
	jq '.abi' "${TOKEN_JSON_PATH}" > "${TOKEN_ABI_PATH}"

.PHONY: abis-compact
abis-compact: build
	@set -e; \
	mkdir -p "${ABI_PATH}"; \
	jq -c '.abi' "${HUB_JSON_PATH}" > "${HUB_ABI_PATH}"; \
	jq -c '.abi' "${FORWARDER_JSON_PATH}" > "${FORWARDER_ABI_PATH}"; \
	jq -c '.abi' "${TOKEN_JSON_PATH}" > "${TOKEN_ABI_PATH}"

.PHONY: docs
docs:
	@forge doc

.PHONY: docs-abis
docs-abis: abis docs docs-openzeppelin
	@set -e; \
	mkdir -p "${ABI_DOC_PATH}"; \
	export PANTOS_REGISTRY_FUNCTIONS=$$(cat "${REGISTRY_DOC_PATH}" | sed '1,/## Functions/d' | sed '/## Events/,$$d'); \
	export PANTOS_TRANSFER_FUNCTIONS=$$(cat "${TRANSFER_DOC_PATH}" | sed '1,/## Functions/d' | sed '/## Events/,$$d'); \
	export PANTOS_REGISTRY_EVENTS=$$(cat "${REGISTRY_DOC_PATH}" | sed '1,/## Events/d'); \
	export PANTOS_TRANSFER_EVENTS=$$(cat "${TRANSFER_DOC_PATH}" | sed '1,/## Events/d'); \
	export PANTOS_HUB_ABI=$$(cat "${HUB_ABI_PATH}"); \
	envsubst < "${HUB_ABI_DOC_TEMPLATE_PATH}" > "${HUB_ABI_DOC_PATH}"; \
	sed -i 's/\[\([^][]*\)\]([^()]*)/\1/g' "${HUB_ABI_DOC_PATH}"; \
	export PANTOS_TOKEN_FUNCTIONS=$$(cat "${TOKEN_DOC_PATH}" | sed '1,/## Functions/d' | sed '/## Events/,$$d'); \
	export ERC20_FUNCTIONS=$$(cat "${ERC20_DOC_PATH}" | sed '1,/## Functions/d' | sed '/## Events/,$$d'); \
	export BEP20_FUNCTIONS=$$(cat "${BEP20_DOC_PATH}" | sed '1,/## Functions/d'); \
	export ERC165_FUNCTIONS=$$(cat "${ERC165_DOC_PATH}" | sed '1,/## Functions/d'); \
	export PANTOS_TOKEN_EVENTS=$$(cat "${TOKEN_DOC_PATH}" | sed '1,/## Events/d'); \
	export ERC20_EVENTS=$$(cat "${ERC20_DOC_PATH}" | sed '1,/## Events/d'); \
	export PANTOS_TOKEN_ABI=$$(cat "${TOKEN_ABI_PATH}"); \
	envsubst < "${TOKEN_ABI_DOC_TEMPLATE_PATH}" > "${TOKEN_ABI_DOC_PATH}"; \
	sed -i 's/\[\([^][]*\)\]([^()]*)/\1/g' "${TOKEN_ABI_DOC_PATH}"

.PHONY: docs-graph
docs-graph:
	@for src_dir in $$(ls -d src/*/); do \
		doc_dir=$$(echo $${src_dir} | sed -e 's/^src/${DOC_PATH}\/graph/g'); \
		mkdir -p $${doc_dir}; \
	done; \
	for src_file in $$(find src/ -name *.sol); do \
		doc_file=$$(echo $${src_file} | sed -e 's/^src/${DOC_PATH}\/graph/g' | sed -e 's/sol$$/png/g'); \
		npx surya graph $${src_file} | dot -Tpng > $${doc_file}; \
	done

.PHONY: docs-inheritance
docs-inheritance:
	@for src_dir in $$(ls -d src/*/); do \
		doc_dir=$$(echo $${src_dir} | sed -e 's/^src/${DOC_PATH}\/inheritance/g'); \
		mkdir -p $${doc_dir}; \
	done; \
	for src_file in $$(find src/ -name *.sol); do \
		doc_file=$$(echo $${src_file} | sed -e 's/^src/${DOC_PATH}\/inheritance/g' | sed -e 's/sol$$/png/g'); \
		npx surya inheritance $${src_file} | dot -Tpng > $${doc_file}; \
	done

.PHONY: docs-openzeppelin
docs-openzeppelin:
	# Output path only partially respected by "forge doc"
	@forge doc --root ${OPENZEPPELIN_LIB_PATH} --out ${OPENZEPPELIN_DOC_PATH}; \
	rm -r -f ${OPENZEPPELIN_LIB_PATH}/${OPENZEPPELIN_DOC_PATH}

.PHONY: docs-all
docs-all: docs docs-abis docs-graph docs-inheritance docs-openzeppelin

# Slither and mythril latest versions are incompatible with each other
.PHONY: analyze-slither
analyze-slither:
	@docker run --platform linux/amd64 -v $$PWD:/share trailofbits/eth-security-toolbox slither /share

.PHONY: analyze-mythril
analyze-mythril:
	@IGNORE_LIST="src/PantosWrapper.sol src/PantosBaseToken.sol src/interfaces/IPantosRegistry.sol src/interfaces/IPantosTransfer.sol src/interfaces/IPantosWrapper.sol src/interfaces/IPantosForwarder.sol src/interfaces/IPantosToken.sol src/interfaces/IBEP20.sol" && \
    IGNORE_FIND=$$(echo $$IGNORE_LIST | sed 's/[^ ]* */! -name &/g') && \
    docker run --platform linux/amd64 -v $$PWD:/share --entrypoint /bin/sh mythril/myth -c 'cd /share && find src -name "*.sol" $${IGNORE_FIND} -print | xargs -I {} sh -c "myth analyze --solc-json mythril.config.json -o markdown {} || echo $$? > mythril_error_code"' && \
    if [ -f mythril_error_code ]; then exit $$(cat mythril_error_code); fi

.PHONY: docker-build
docker-build:
	docker buildx bake -f docker-compose.yml --load --pull $(ARGS)

.PHONY: check-swarm-init
check-swarm-init:
	@if [ "$$(docker info --format '{{.Swarm.LocalNodeState}}')" != "active" ]; then \
        echo "Docker is not part of a swarm. Initializing..."; \
        docker swarm init; \
    else \
        echo "Docker is already part of a swarm."; \
    fi

.PHONY: docker
docker: check-swarm-init
	@for i in $$(seq 1 $(INSTANCE_COUNT)); do \
        ( \
        export STACK_NAME="${STACK_BASE_NAME}-${STACK_IDENTIFIER}-$$i"; \
        export DATA_PATH=./data/$$STACK_NAME; \
        export INSTANCE=$$i; \
        echo "Deploying stack $$STACK_NAME"; \
        if [ "$(DEV_MODE)" = "true" ]; then \
            echo "Running in development mode"; \
            export ARGS="$(ARGS) --watch"; \
            echo "Running docker compose with ARGS: $$ARGS"; \
            docker compose -f docker-compose.yml -f docker-compose.ci.yml -p $$STACK_NAME $$EXTRA_COMPOSE up $$ARGS & \
            COMPOSE_PID=$$!; \
            trap 'echo "Caught INT, killing background processes..."; kill $$COMPOSE_PID; exit 1' INT; \
        else \
            export ARGS="--detach --wait $(ARGS)"; \
            echo "Running docker compose with ARGS: $$ARGS"; \
            docker compose -f docker-compose.yml -f docker-compose.ci.yml -p $$STACK_NAME $$EXTRA_COMPOSE up $$ARGS; \
        fi; \
        trap 'exit 1' INT; \
        for service in $$(yq e '.services | with_entries(select(.value.image | contains("ethereum-node"))) | keys | .[]' docker-compose.yml); do \
            if [ "$(DEV_MODE)" = "true" ]; then \
                echo "Waiting for $$STACK_NAME-$$service-1 to be healthy"; \
                while [ "$$(docker inspect --format='{{.State.Health.Status}}' $$STACK_NAME-$$service-1)" != "healthy" ]; do \
                    echo "Waiting for $$STACK_NAME-$$service-1 to be healthy..."; \
                    sleep 5; \
                done; \
                echo "$$STACK_NAME-$$service-1 is healthy"; \
            fi; \
			if [ "$$(docker inspect --format='{{.State.Health.Status}}' $$STACK_NAME-$$service-1)" == "unhealthy" ]; then \
				echo "Service $$STACK_NAME-$$service-1 is not healthy, status: $$status"; \
				docker logs $$STACK_NAME-$$service-1; \
			fi; \
            dir=$$DATA_PATH/$$service; \
            echo "Copying data from $$service to $$dir"; \
            mkdir -p $$dir; \
            docker cp $$STACK_NAME-$$service-1:/data $$dir; \
            cp -rf $$dir/data/* $$dir; \
            rm -rf $$dir/data; \
        done; \
        echo "Stack $$STACK_NAME deployed"; \
        if [ "$(DEV_MODE)" = "true" ]; then \
            wait $$COMPOSE_PID; \
        fi; \
        ) & \
    done; \
    trap 'echo "Caught INT, killing all background processes..."; kill 0; exit 1' INT; \
    wait
    # We need to use compose because swarm goes absolutely crazy on MacOS when using cross architecture
    # And can't pull the correct images
    # docker stack deploy -c docker-compose.yml $(EXTRA_COMPOSE) $$STACK_NAME --with-registry-auth --detach=false $(ARGS); \

.PHONY: docker-local
docker-local:
	@make docker EXTRA_COMPOSE="-f docker-compose.local.yml"

.PHONY: docker-remove
docker-remove:
	@STACK_NAME="${STACK_BASE_NAME}"; \
    if [ -n "$(STACK_IDENTIFIER)" ]; then \
        STACK_NAME="$$STACK_NAME-$(STACK_IDENTIFIER)"; \
        echo "Removing the stack with identifier $(STACK_IDENTIFIER)"; \
    else \
        echo "** Removing all stacks **"; \
    fi; \
	for stack in $$(docker stack ls --format "{{.Name}}" | awk "/^$$STACK_NAME/ {print}"); do \
        ( \
        echo "Removing stack $$stack"; \
        docker stack rm $$stack --detach=false; \
		echo "Removing volumes for stack $$stack"; \
        docker volume ls --format "{{.Name}}" | awk '/^$$stack/ {print}' | xargs -r docker volume rm; \
        rm -Rf ./data/$$stack; \
        ) & \
    done;  \
    for compose_stack in $$(docker compose ls --filter "name=$$STACK_NAME" --format json | jq -r '.[].Name' | awk "/^$$STACK_NAME/ {print}"); do \
        ( \
        echo "Removing Docker Compose stack $$compose_stack"; \
        docker compose -p $$compose_stack down -v; \
        rm -Rf ./data/$$compose_stack; \
        ) & \
    done; \
    wait

.PHONY: docker-logs
docker-logs:
	@for stack in $$(docker stack ls --format "{{.Name}}" | awk '/^${STACK_BASE_NAME}-${STACK_IDENTIFIER}/ {print}'); do \
        echo "Showing logs for stack $$stack"; \
        for service in $$(docker stack services --format "{{.Name}}" $$stack); do \
            echo "Logs for service $$service in stack $$stack"; \
            docker service logs --no-task-ids $$service; \
        done; \
    done
