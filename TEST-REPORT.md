# Test report and execution status

## Verified successfully on GitHub Actions

Run: [Assignment CI #42397362918](https://github.com/motasem33/progresssoft-assignment/actions/runs/42397362918)

The Ubuntu runner completed successfully on 2026-11-07. It verified Bash syntax and ShellCheck, Ruby syntax and the required Vagrantfile values, YAML parsing for Docker Compose and Kubernetes manifests, Docker Compose configuration, a real Nginx/PostgreSQL Compose stack with an HTTP request through the reverse proxy, creation of a minimal sample WAR, and a real Docker build of the Tomcat image.

The Compose test used disposable sample credentials from `.env.example`; no credentials were committed. The WAR was generated inside the CI workspace and was not added to the repository.

## Not executed and honestly marked as environment-dependent

The Oracle SQL/PLSQL script was not executed because this environment does not contain an Oracle Database. It must be run in an approved Oracle 12c+ schema and the results for Q2–Q6 should be captured before final submission.

The Vagrantfile syntax was checked, but `vagrant up` with VirtualBox was not run because the GitHub runner has no VirtualBox VM environment. The Kubernetes manifest YAML was parsed, but no cluster deployment was performed because no Kubernetes API server was available. The Docker image was built in CI, but it was not pushed to a registry because no registry namespace or credentials were supplied.

The repository does not claim that passwords, host users, host firewalls, Oracle, VirtualBox, Kubernetes cluster deployment, or registry push were executed. The original confidential PDF, passwords, keys, VM files, database dumps, and WAR binaries are not included.

## Recommended final evidence if ProgressSoft requests a full lab run

Run the Oracle script in a disposable approved schema and record the output for Q2–Q6. If a lab VM is available, run `vagrant validate` and then `vagrant up`, capture `java -version`, Tomcat status, port 7070, and the forwarded port 9090. If a registry is provided, authenticate through the approved mechanism, push the image, record its immutable digest, and update the Kubernetes image reference only in an approved cluster.
