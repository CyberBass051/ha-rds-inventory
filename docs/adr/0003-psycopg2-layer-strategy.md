# ADR 0003: psycopg2 Lambda Layer Strategy

## Status
Accepted

## Context
The db-bootstrap Lambda needs a PostgreSQL driver to connect directly to the
Aurora cluster and create the application database role. psycopg2 requires
compiled C bindings (libpq), which cannot simply be `pip install`-ed into a
Lambda deployment package — it must be supplied as a Lambda layer built for
the target runtime and architecture.

Three approaches were evaluated, in this order:

1. **Public layer — jetbridge/psycopg2-lambda-layer.** Rejected: this project
   published no build past Python 3.7, and the Lambda runtime here is 3.12.

2. **Public layer — Klayers (keithrozario/Klayers).** Verified the
   `python3.12` deployment path exists in the repository, but no
   `psycopg2`/`psycopg2-binary` layer is published for `us-east-1` under that
   runtime. Checked `python3.11` as a fallback — same result, no matching
   layer published for this region. Both attempts confirmed via direct
   queries against the project's manifest, not assumed from documentation.

3. **Self-built layer**, via Docker against `amazonlinux:2023` (matching
   Lambda's actual execution environment), publishing the result under this
   project's own AWS account.

During evaluation, the development environment (a ship with a slow,
intermittent internet connection) made the Docker-based build painful — an
initial attempt appeared to hang for 40+ minutes before being interrupted.
`pg8000`, a pure-Python PostgreSQL driver requiring no compiled layer at
all, was considered as a bandwidth-constrained alternative and a working
handler was written against it.

The interrupted Docker build was later discovered to have completed
successfully in the background, producing a valid, verified layer artifact
(confirmed via `unzip -l` and `unzip -t` — correct package contents, no
corruption). The layer was published successfully to this project's AWS
account.

## Decision
Use the self-built psycopg2 layer (`ha-rds-psycopg2-py312`) with the
original psycopg2-based handler code, rather than switching to `pg8000`.

## Consequences
- The project depends on a layer built and owned entirely within this AWS
  account — no third-party account dependency, unlike the jetbridge/Klayers
  paths that were rejected.
- Rebuilding this project from scratch on a new AWS account requires
  re-running the Docker build and republishing the layer; this is a real
  but acceptable maintenance cost, documented here rather than left as a
  silent prerequisite.
- A working `pg8000`-based handler was written during the bandwidth-
  constrained period but was not used, since the psycopg2 layer became
  available and already-reviewed code was preferred over a rewrite for its
  own sake.
- The layer ARN itself is account- and environment-specific and is not
  hardcoded into the Terraform module — see ADR 0004.

## Alternatives Considered
- **jetbridge/psycopg2-lambda-layer** — rejected, no Python 3.12 support.
- **Klayers** — rejected, no psycopg2 build published for this runtime/
  region combination at time of writing; confirmed by direct query rather
  than assumption.
- **pg8000** — a viable, dependency-free alternative that was implemented
  and validated but ultimately not used once the self-built layer succeeded.
  Worth revisiting if this project's AWS account ever changes and the layer
  needs to be rebuilt under worse network conditions again.