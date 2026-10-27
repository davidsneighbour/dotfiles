---
applyTo: "containers/**"
---

# Docker and containers

Containers are managed via **Docker Compose**.

Rules:

* Volumes should be local to the compose file where possible
* Paths must be explicit
* No hidden bind mounts
* No reliance on Docker Desktop features
* Compose files must be readable without external context

The repository prefers *few well-structured containers* over many small ones.
