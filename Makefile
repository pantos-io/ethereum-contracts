STACK_BASE_NAME=stack-ethereum-contracts
INSTANCE_COUNT ?= 1

.PHONY: build
build:
	forge build

.PHONY: clean
clean:
	forge clean

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
        docker compose -f docker-compose.yml -f docker-compose.ci.yml $(EXTRA_COMPOSE) up -d --wait $(ARGS); \
        for service in $$(yq e '.services | with_entries(select(.value.image | contains("ethereum-node"))) | keys | .[]' docker-compose.yml); do \
            dir=$$DATA_PATH/$$service; \
            echo "Copying data from $$service to $$dir"; \
            mkdir -p $$dir; \
            docker cp $$STACK_NAME-$$service-1:/data $$dir; \
            mv $$dir/data/* $$dir; \
            rmdir $$dir/data; \
        done; \
        ) & \
    done; \
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
