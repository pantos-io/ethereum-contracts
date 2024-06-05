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
	forge test

.PHONY: coverage
coverage:
	forge coverage --ir-minimum

.PHONY: snapshot
snapshot:
	forge snapshot

.PHONY: analyze-slither
analyze-slither:
	-( \
       echo Analyzing using Slither; \
	   python3 -m venv .venv; \
       . ./.venv/bin/activate; \
	   pip install --upgrade pip; \
       pip install slither-analyzer; \
       slither .; \
    )


.PHONY: analyze-mythril
analyze-mythril:
	-( \
       echo Analyzing using mythril on single file; \
	   python3 -m venv .venv; \
       . ./.venv/bin/activate; \
	   pip install --upgrade pip; \
       pip install mythril; \
       myth analyze src/PantosToken.sol --solc-json mythril.config.json; \
    )
