## Same as build, the target of a bare `make`
default: build
## List the targets with their description
help:
	@awk '/^## / { desc = substr($$0, 4); next } /^[a-z][a-z0-9-]*:/ && desc { sub(/:.*/, "", $$1); printf "  %-18s %s\n", $$1, desc } { desc = "" }' ${MAKEFILE_LIST}

COMPOSE_FILE="docker-compose.yaml"
SSH_KEY=admin/ssh/id_ed25519
SSH_OPTS=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ${SSH_KEY}
# Kubernetes workers, the replicas of the k8s-worker service: `workers=N` scales
# them; otherwise the lab keeps the workers it has, 4 on a fresh start.
WORKERS=$(or $(workers),$(shell docker compose -f ${COMPOSE_FILE} ps --all --quiet k8s-worker 2>/dev/null | wc -l | awk '$$1 > 0 { print $$1 }'),4)
# `service=k8s-worker-N` is replica N of the k8s-worker service.
SERVICE=$(if $(filter k8s-worker-%,$(service)),--index $(service:k8s-worker-%=%) k8s-worker,$(service))

# Cookstyle and ChefSpec run in the Cinc Workstation image; no Ruby on the host.
# `cookbook=admin` (or k8s, slurm) restricts lint-chef and test-chef to one cookbook.
CHEF_RUN=docker run --rm -v $(CURDIR):/workspace -w /workspace cincproject/workstation:26.3.0
COOKBOOKS=$(or $(cookbook),admin k8s slurm)
# ShellCheck lints every tracked shell script, found by the shebang on its first
# line (a shebang further down, e.g. in a docs example, does not count);
# .shellcheckrc holds the checks disabled for the whole repo.
SHELLCHECK_RUN=docker run --rm -v $(CURDIR):/mnt -w /mnt koalaman/shellcheck:v0.11.0
SHELL_SCRIPTS=$(shell git ls-files | LC_ALL=C xargs awk 'FNR == 1 && /^\#!\/(usr\/)?bin\/(env )?(ba)?sh/ { print FILENAME }')

## Start the Docker daemon if it is not running
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

## Install the host prerequisites (Docker, Compose, GNU Make)
setup:
	bash resources/tools/setup-dev-environment.sh
## Build the images (service=NAME for one)
build: docker-check
	docker compose -f ${COMPOSE_FILE} build $(service)
## Build, start Kubernetes, deploy Slurm, then describe the lab
start: build start-k8s start-slurm
	@$(MAKE) describe
## Stop the containers (service=NAME for one)
stop: docker-check
	docker compose -f ${COMPOSE_FILE} stop $(service)
## Stop, then start
restart: stop start
## Destroy everything, then start from scratch
redeploy: clean start
# A recreated container mounts the anonymous volumes of the one it replaces by
# name, so `down --volumes` leaves them behind: collect the volumes of every
# container first and remove whatever is left after `down`.
## Destroy the containers, local images and volumes
clean: docker-check
	volumes="$$(docker compose -f ${COMPOSE_FILE} ps --all --quiet | xargs -r docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}')" && \
	docker compose -f ${COMPOSE_FILE} down --rmi local --volumes --remove-orphans && \
	echo $${volumes} | xargs -r docker volume rm --force >/dev/null
## List the containers with their state and URL
show:
	@docker compose -f ${COMPOSE_FILE} ps --format json | \
		jq -rs '["SERVICE","STATE","HEALTH","URL"], (.[] | . as $$svc | (.Publishers[]? | select(.PublishedPort != 0 and .URL == "127.0.0.1") | [$$svc.Service, $$svc.State, $$svc.Status, "http://localhost:\(.PublishedPort)"]), (select([.Publishers[]? | select(.PublishedPort != 0 and .URL == "127.0.0.1")] | length == 0) | [.Service, .State, .Status, "-"])) | @tsv' | \
		column -t -s $$'\t' | \
		sort -u
## Show the containers, the Kubernetes nodes and pods, and sinfo
describe:
	@$(MAKE) show
	-docker compose -f ${COMPOSE_FILE} exec -T admin kubectl get nodes
	-docker compose -f ${COMPOSE_FILE} exec -T admin kubectl get pods --all-namespaces
	-docker compose -f ${COMPOSE_FILE} exec -T admin slurm-exec sinfo
## Last 500 log lines of a service (service=NAME, k8s-worker-N for a worker)
get-logs:
	docker compose -f ${COMPOSE_FILE} logs ${SERVICE} | tail -n 500
## Bash shell in a service (service=NAME, k8s-worker-N for a worker)
login:
	docker compose -f ${COMPOSE_FILE} exec -it ${SERVICE} /bin/bash

## Start the Kubernetes cluster (workers=N scales the workers)
start-k8s: docker-check k8s/.env.secrets.local ${SSH_KEY}
	@# Compose leaves the anonymous volumes of the replicas a scale-down removes;
	@# remove the replicas beyond WORKERS, with their volumes, before scaling.
	docker compose -f ${COMPOSE_FILE} ps --all --format '{{.Name}}' k8s-worker | awk -F- '$$NF > ${WORKERS}' | xargs -r docker rm --force --volumes
	docker compose -f ${COMPOSE_FILE} up --detach --wait --scale k8s-worker=${WORKERS}
	docker compose -f ${COMPOSE_FILE} exec -T admin k8s-wait ${WORKERS}
## Stop every container, keeping the cluster state
stop-k8s: docker-check
	docker compose -f ${COMPOSE_FILE} stop
## Health check of the Kubernetes cluster
test-k8s:
	docker compose -f ${COMPOSE_FILE} exec -T admin k8s-test
## Deploy or upgrade the Slurm cluster from the cookbook attributes
start-slurm: docker-check
	docker compose -f ${COMPOSE_FILE} exec -T admin slurm-deploy
## Remove the Slurm cluster, keep Kubernetes
stop-slurm: docker-check
	docker compose -f ${COMPOSE_FILE} exec -T admin slurm-destroy
## Submit a hello world batch job
test-slurm:
	docker compose -f ${COMPOSE_FILE} exec -T admin slurm-test

## Lint the cookbooks with Cookstyle (cookbook=NAME for one)
lint-chef: docker-check
	${CHEF_RUN} cookstyle $(foreach c,${COOKBOOKS},$(wildcard $(c)/client.rb) $(c)/cookbook)
## Unit-test the cookbooks with ChefSpec (cookbook=NAME for one)
test-chef: docker-check
	${CHEF_RUN} bash -c 'set -e; for c in ${COOKBOOKS}; do (cd "$$c/cookbook" && cinc exec rspec); done'
## Lint the shell scripts with ShellCheck
lint-shell: docker-check
	${SHELLCHECK_RUN} -x ${SHELL_SCRIPTS}
## Check that every Makefile target has a description for help
lint-make:
	@awk '/^[a-z][a-z0-9-]*:/ && !/^[^:]*:=/ { if (prev !~ /^## /) { sub(/:.*/, "", $$1); print "no description for help: " $$1; bad = 1 } } { prev = $$0 } END { exit bad }' ${MAKEFILE_LIST}
## Run every linter
lint: lint-chef lint-shell lint-make
## Lint, then unit-test the cookbooks
test: lint test-chef

## SSH into the admin node
ssh-admin:
	ssh ${SSH_OPTS} -p $$(docker compose -f ${COMPOSE_FILE} port admin 22 | cut -d: -f2) root@localhost
## Shell on the Slurm login node
ssh-slurm-login:
	docker compose -f ${COMPOSE_FILE} exec -it admin slurm-shell login
## Shell on the Slurm head node (slurmctld)
ssh-slurm-head:
	docker compose -f ${COMPOSE_FILE} exec -it admin slurm-shell head
## Shell on a Slurm compute node (node=NAME, default cmpt-0)
ssh-slurm-compute:
	docker compose -f ${COMPOSE_FILE} exec -it admin slurm-shell compute $(or $(node),cmpt-0)
## Generate the lab SSH keypair, keeping an existing one
ssh-key: ${SSH_KEY}
	@echo "lab keypair: ${SSH_KEY} ($$(ssh-keygen -lf ${SSH_KEY}.pub))"
## Write a host kubeconfig and print the export to use it
kubeconfig:
	@docker compose -f ${COMPOSE_FILE} exec -T admin sed "s|https://k8s-control-plane:6443|https://127.0.0.1:$$(docker compose -f ${COMPOSE_FILE} port k8s-control-plane 6443 | cut -d: -f2)|" /root/.kube/config > k8s/kubeconfig.local
	@echo "export KUBECONFIG=$(CURDIR)/k8s/kubeconfig.local"

k8s/.env.secrets.local:
	@printf '# kubeadm bootstrap token shared by the control plane and the workers. Generated.\nK8S_TOKEN=%s\n' "$$(openssl rand -hex 3).$$(openssl rand -hex 8)" > $@
# Generated once; make never rebuilds an existing file, so a keypair is kept.
${SSH_KEY}:
	@mkdir -p admin/ssh
	@ssh-keygen -q -t ed25519 -N "" -C hpc-lab -f ${SSH_KEY}
