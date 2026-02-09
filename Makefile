.PHONY: setup install

PROJECT_NAME="hpc-lab"
COMPOSE_FILE="docker-compose.yaml"

PYTHON_VERSION = 3.14.2
VENV_NAME = hpc-lab-dev

docker-check:
	@if ! docker info >/dev/null 2>&1; then \
		echo "Docker daemon is not running. Starting Docker..."; \
		if [[ "$$OSTYPE" == "darwin"* ]]; then \
			open -a Docker; \
			echo "Waiting for Docker Desktop to start..."; \
			while ! docker info >/dev/null 2>&1; do sleep 2; done; \
		elif [[ "$$OSTYPE" == "linux-gnu"* ]]; then \
			sudo systemctl start docker; \
			while ! docker info >/dev/null 2>&1; do sleep 2; done; \
		else \
			echo "Unsupported OS. Please start Docker manually."; \
			exit 1; \
		fi; \
		echo "Docker daemon started successfully."; \
	fi

setup:
	bash tools/setup-dev-environment.sh

build: docker-check
	docker compose -f ${COMPOSE_FILE} pull $(container)
	docker compose -f ${COMPOSE_FILE} build $(container)

start: docker-check
	docker compose -f ${COMPOSE_FILE} up --detach $(container)
	@$(MAKE) print-endpoints

restart: docker-check
	docker compose -f ${COMPOSE_FILE} restart $(container)
	@$(MAKE) print-endpoints

stop: docker-check
	docker compose -f ${COMPOSE_FILE} stop $(container)

clean: docker-check
	@docker compose -f ${COMPOSE_FILE} rm --force --stop --volumes 2>/dev/null || true
	@images=$$(docker compose -f ${COMPOSE_FILE} config --images 2>/dev/null); \
	if [ -n "$$images" ]; then \
		docker rmi --force $$images 2>/dev/null || true; \
	fi
	@volumes=$$(docker compose -f ${COMPOSE_FILE} config --volumes 2>/dev/null | sed "s/^/${PROJECT_NAME}_/"); \
	if [ -n "$$volumes" ]; then \
		docker volume rm --force ${PROJECT_NAME}_srvdata $$volumes 2>/dev/null || true; \
	fi

describe: docker-check
	docker compose -f ${COMPOSE_FILE} ps

get-logs: docker-check
	docker compose -f ${COMPOSE_FILE} logs $(container) | tail -n 500

login: docker-check
	docker compose -f ${COMPOSE_FILE} exec -it $(container) /bin/bash

install:
	pip install -e .

test:
	tox

install-docs:
	pip install -e ".[docs]"

build-docs: install-docs
	$(MAKE) -C docs html

clean: clean-docs

clean-docs: install-docs
	$(MAKE) -C docs clean

open-docs:
	open docs/_build/html/index.html
