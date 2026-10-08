default: build

COMPOSE_FILE="docker-compose.yaml"
SSH_KEY=admin/ssh/id_ed25519
SSH_OPTS=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ${SSH_KEY}

# Cookstyle and ChefSpec run in the Cinc Workstation image; no Ruby on the host.
# `cookbook=admin` (or k8s, slurm) restricts lint-chef and test-chef to one cookbook.
CHEF_RUN=docker run --rm -v $(CURDIR):/workspace -w /workspace cincproject/workstation:26.3.0
COOKBOOKS=$(or $(cookbook),admin k8s slurm)
# ShellCheck lints every tracked shell script, found by the shebang on its first
# line (a shebang further down, e.g. in a docs example, does not count);
# .shellcheckrc holds the checks disabled for the whole repo.
SHELLCHECK_RUN=docker run --rm -v $(CURDIR):/mnt -w /mnt koalaman/shellcheck:v0.11.0
SHELL_SCRIPTS=$(shell git ls-files | LC_ALL=C xargs awk 'FNR == 1 && /^\#!\/(usr\/)?bin\/(env )?(ba)?sh/ { print FILENAME }')

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
	else \
		echo "Docker daemon is running"; \
	fi

setup:
	bash resources/tools/setup-dev-environment.sh
build: docker-check
	docker compose -f ${COMPOSE_FILE} build $(service)
start: build start-k8s start-slurm
	@$(MAKE) describe
stop: docker-check
	docker compose -f ${COMPOSE_FILE} stop $(service)
restart: stop start
redeploy: clean start
clean: docker-check
	docker compose -f ${COMPOSE_FILE} down --rmi local --volumes --remove-orphans
show:
	@docker compose -f ${COMPOSE_FILE} ps --format json | \
		jq -rs '["SERVICE","STATE","HEALTH","URL"], (.[] | . as $$svc | (.Publishers[]? | select(.PublishedPort != 0 and .URL == "127.0.0.1") | [$$svc.Service, $$svc.State, $$svc.Status, "http://localhost:\(.PublishedPort)"]), (select([.Publishers[]? | select(.PublishedPort != 0 and .URL == "127.0.0.1")] | length == 0) | [.Service, .State, .Status, "-"])) | @tsv' | \
		column -t -s $$'\t' | \
		sort -u
describe:
	@$(MAKE) show
	-docker compose -f ${COMPOSE_FILE} exec -T admin kubectl get nodes
	-docker compose -f ${COMPOSE_FILE} exec -T admin kubectl get pods --all-namespaces
	-docker compose -f ${COMPOSE_FILE} exec -T admin slurm-exec sinfo
get-logs:
	docker compose -f ${COMPOSE_FILE} logs $(service) | tail -n 500
login:
	docker compose -f ${COMPOSE_FILE} exec -it $(service) /bin/bash

start-k8s: docker-check k8s/.env.secrets.local ${SSH_KEY}
	docker compose -f ${COMPOSE_FILE} up --detach --wait
	docker compose -f ${COMPOSE_FILE} exec -T admin k8s-wait
stop-k8s: docker-check
	docker compose -f ${COMPOSE_FILE} stop
test-k8s:
	docker compose -f ${COMPOSE_FILE} exec -T admin k8s-test
start-slurm: docker-check
	docker compose -f ${COMPOSE_FILE} exec -T admin slurm-deploy
stop-slurm: docker-check
	docker compose -f ${COMPOSE_FILE} exec -T admin slurm-destroy
test-slurm:
	docker compose -f ${COMPOSE_FILE} exec -T admin slurm-test

lint-chef: docker-check
	${CHEF_RUN} cookstyle $(foreach c,${COOKBOOKS},$(wildcard $(c)/client.rb) $(c)/cookbook)
test-chef: docker-check
	${CHEF_RUN} bash -c 'set -e; for c in ${COOKBOOKS}; do (cd "$$c/cookbook" && cinc exec rspec); done'
lint-shell: docker-check
	${SHELLCHECK_RUN} -x ${SHELL_SCRIPTS}
lint: lint-chef lint-shell
test: lint test-chef

ssh-admin:
	ssh ${SSH_OPTS} -p $$(docker compose -f ${COMPOSE_FILE} port admin 22 | cut -d: -f2) root@localhost
ssh-slurm-login:
	docker compose -f ${COMPOSE_FILE} exec -it admin slurm-shell login
ssh-slurm-head:
	docker compose -f ${COMPOSE_FILE} exec -it admin slurm-shell head
ssh-slurm-compute:
	docker compose -f ${COMPOSE_FILE} exec -it admin slurm-shell compute $(or $(node),cmpt-0)
ssh-key: ${SSH_KEY}
	@echo "lab keypair: ${SSH_KEY} ($$(ssh-keygen -lf ${SSH_KEY}.pub))"
kubeconfig:
	@docker compose -f ${COMPOSE_FILE} exec -T admin sed "s|https://k8s-control-plane:6443|https://127.0.0.1:$$(docker compose -f ${COMPOSE_FILE} port k8s-control-plane 6443 | cut -d: -f2)|" /root/.kube/config > k8s/kubeconfig.local
	@echo "export KUBECONFIG=$(CURDIR)/k8s/kubeconfig.local"

k8s/.env.secrets.local:
	@printf '# kubeadm bootstrap token shared by the control plane and the workers. Generated.\nK8S_TOKEN=%s\n' "$$(openssl rand -hex 3).$$(openssl rand -hex 8)" > $@
# Generated once; make never rebuilds an existing file, so a keypair is kept.
${SSH_KEY}:
	@mkdir -p admin/ssh
	@ssh-keygen -q -t ed25519 -N "" -C hpc-lab -f ${SSH_KEY}
