.PHONY: code
code: check format lint sort test

.PHONY: check
check:
	mypy cli

.PHONY: format
format:
	yapf --in-place --recursive cli

.PHONY: lint
lint:
	flake8 cli

.PHONY: sort
sort:
	isort --force-single-line-imports cli tests

.PHONY: test
test:
	python -m pytest tests

.PHONY: coverage
coverage:
	python3 -m pytest --cov-report term-missing --cov=pantos tests
	rm .coverage
