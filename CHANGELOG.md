# Changelog

## 1.0.0

🎉 **Initial Release**

- The lab: a Kubernetes cluster with a Slurm cluster deployed through the Slinky operator, all containerized as a Docker Compose project.
- Every container is configured by Chef (Cinc Client in local mode, one cookbook per component folder) at image build and at container start; the Slurm layer is deployed by a Chef recipe, and its settings are cookbook attributes.
- Kubernetes v1.36.4
- Slurm 26.05
- Slinky 1.2.3
- cert-manager v1.21.2
- Cinc Client 19.3.14
- Docker images:
  - admin node: `registry.access.redhat.com/ubi9/ubi:9.8`
- `make lint` lints the cookbooks (Cookstyle) and the shell scripts (ShellCheck); `make test` also unit-tests the cookbooks (ChefSpec).
