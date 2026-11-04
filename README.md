# ProgressSoft Associate Support Engineer Assignment

This repository contains a structured, reviewable solution for the ProgressSoft assignment. It is intentionally split into documentation, SQL/PLSQL, Linux scripts, Vagrant provisioning, Docker, Compose, and Kubernetes examples.

## Important scope and safety notes

- The commands are written for a disposable Ubuntu VM or approved lab environment. Do not run account, firewall, password, database, or virtualization commands on a production host without authorization.
- No passwords, private keys, database dumps, WAR binaries, VM disks, or registry credentials are included.
- Commands that would change an external system are documented but are not claimed as executed unless explicitly marked in `TEST-REPORT.md`.
- Replace placeholders such as `app.example.com`, registry names, image tags, and the Tomcat version with approved values before execution.

## Repository map

- `docs/linux.md` — Linux tasks, security notes, system information script, users, packages, firewall, file transfer, and Linux overview.
- `docs/sql.md` — SQL/PLSQL concepts and exact answers for Q1–Q6.
- `sql/hr_assignment.sql` — Oracle SQL/PLSQL script with schema, seed data, Q2–Q6, function, and procedure.
- `docs/tomcat.md` — JVM, application server, WAR, Tomcat, Nginx reverse proxy, and Vagrant notes.
- `Vagrantfile` and `provision-tomcat.sh` — requested VM definition and provisioning.
- `docker/Dockerfile.tomcat9` — Tomcat image definition requiring a real WAR at build time.
- `docker/docker-compose.yml` — local Nginx and PostgreSQL example.
- `docker/nginx/default.conf` — safe HTTP reverse-proxy placeholder for an application service.
- `k8s/sample-tomcat.yaml` — namespace, deployment, and service example.
- `scripts/system_info.sh` — dynamic Linux system information report.
- `TEST-REPORT.md` — explicit test status and local verification checklist.

## Suggested review/run order

1. Read the four documents and inspect every placeholder.
2. Run `shellcheck scripts/system_info.sh` and `bash -n scripts/system_info.sh`.
3. Run the Oracle script only in an approved Oracle schema, preferably a disposable schema.
4. Put a real, approved WAR in `docker/app/sample-app.war`, then run `docker compose config` and build locally.
5. Run `vagrant validate`; only run `vagrant up` on a machine with VirtualBox and explicit authorization.
6. Apply the Kubernetes manifest only to a disposable cluster after replacing the image reference.
7. Commit with a meaningful message, push to a private or employer-approved repository, and send the repository URL and a short completion note to ProgressSoft.

## Assignment submission

The original PDF is confidential and should not be committed to a public repository. Submit the repository link only through the email channel requested by ProgressSoft, and keep the repository private unless they explicitly request otherwise.
