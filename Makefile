default: build

COMPOSE_FILE="docker-compose.yaml"
SSH_KEY=admin/ssh/id_ed25519
SSH_OPTS=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ${SSH_KEY}

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
	docker compose -f ${COMPOSE_FILE} up --detach
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

ssh-admin:
	ssh ${SSH_OPTS} -p $$(docker compose -f ${COMPOSE_FILE} port admin 22 | cut -d: -f2) root@localhost
ssh-slurm-login:
	docker compose -f ${COMPOSE_FILE} exec -it admin slurm-shell login
ssh-slurm-head:
	docker compose -f ${COMPOSE_FILE} exec -it admin slurm-shell head
ssh-slurm-compute:
	docker compose -f ${COMPOSE_FILE} exec -it admin slurm-shell compute $(or $(node),cpu-0)
kubeconfig:
	@docker compose -f ${COMPOSE_FILE} exec -T admin sed "s|https://k8s-control-plane:6443|https://127.0.0.1:$$(docker compose -f ${COMPOSE_FILE} port k8s-control-plane 6443 | cut -d: -f2)|" /root/.kube/config > k8s/kubeconfig.local
	@echo "export KUBECONFIG=$(CURDIR)/k8s/kubeconfig.local"

k8s/.env.secrets.local:
	@printf '# kubeadm bootstrap token shared by the control plane and the workers. Generated.\nK8S_TOKEN=%s\n' "$$(openssl rand -hex 3).$$(openssl rand -hex 8)" > $@
${SSH_KEY}:
	@mkdir -p admin/ssh
	@ssh-keygen -q -t ed25519 -N "" -C hpc-lab -f ${SSH_KEY}
