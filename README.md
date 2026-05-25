# p1-connector

A lightweight Ruby runtime for file-based integration with the P1 platform.

## Who This Project Is For

This tool is being prepared for an integrator who wants to run batch tasks provided as JSON files and receive results as JSON files plus audit entries.

At the current stage, the project provides a local one-shot `run-once` mode, a continuous `watch` mode based on `Sidekiq`, `sidekiq-cron`, and `Redis`, the operator `recover` command, and the helper MVP deployment tool `p1-live-smoke`.

## What Works Now

Currently available:

- YAML configuration file validation
- P1 environment selection: `integration` (`isus.ezdrowie.gov.pl`) or `production` (`sus.ezdrowie.gov.pl`)
- P1 communication based on WSS JWT + mutual TLS
- processing a single JSON file in `run-once` mode
- continuous `watch` mode with embedded `Sidekiq`
- periodic `inbox` scanning through `sidekiq-cron`
- enqueueing a processing job after an atomic `inbox -> processing` file takeover
- minimal retry policy for technical errors: at most 2 attempts total
- minimal input contract validation
- business operations:
  - `register_encounter`
  - `register_procedure`
  - `register_condition`
  - `register_provenance`
  - `get_resource`
  - `destroy_resource`
- real `register_encounter` integration with P1:
  - token retrieval
  - patient lookup
  - patient creation if the patient does not exist
  - `Encounter` creation or update
- real `register_procedure`, `register_condition`, and `register_provenance` integration with P1
- real integration with `signature-service` for `register_provenance`
- writing the result to a JSON file
- writing technical audit data to a JSON Lines file

## Requirements

- Docker and `docker compose` for the default setup without local Ruby
- Ruby `3.4.9` and Bundler only for the local Ruby variant

## Local Ruby Setup

1. Install dependencies:

```bash
bundle install
```

2. Prepare the application configuration:

```bash
cp config/config.example.yml config/config.yml
```

3. Optionally prepare local environment variables based on `.env.example`:

```bash
cp .env.example .env
```

Important:

- `bin/p1-tool` automatically loads `.env` if the file exists
- before running `verify`, `run-once`, or `watch`, set valid `WSS_CERT_PASSWORD` and `TLS_CERT_PASSWORD`
- `recover` does not require certificate passwords or P1 access; it loads configuration without runtime validation
- adjust `P1_CERTIFICATES_BASE_PATH` to the location of your certificates; the example `config/config.example.yml` points to `./volumes/certs` by default

4. If you want to run Redis through Compose for local Ruby:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

The `.env.example` file describes the local Ruby runtime model. `docker-compose.dev.yml` is only used to expose local helper services.

## Configuration

Example configuration is available in `config/config.example.yml`.

Configuration covers:

- working directories: `inbox`, `processing`, `done`, `invalid`, `results`
- path to the `audit_log` file
- `redis` settings
- `Sidekiq` configuration in `config/sidekiq.yml`
- `sidekiq-cron` schedule in `config/sidekiq-cron.yml`
- `signature_service` address
- P1 configuration in the `p1` section
- `subject` data
- `wss` and `tls` certificate configuration

Fields required by the configuration schema:

- `paths.inbox`, `paths.processing`, `paths.done`, `paths.invalid`, `paths.results`, `paths.audit_log`
- `redis.url`
- `signature_service.url`
- `p1.environment`
- `subject.oid`, `subject.identification_code`, `subject.department_code_v`, `subject.department_code_vii`, `subject.is_practice`, `subject.medical_chamber`
- `certificates.base_path`
- `certificates.wss.filename`, `certificates.wss.password_env`
- `certificates.tls.filename`, `certificates.tls.password_env`

Important:

- in `run-once` mode, the result is written to the path passed through `--output`
- the audit file is written to the `paths.audit_log` path from configuration
- working directories `inbox`, `processing`, `done`, `invalid`, and `results` must be on the same filesystem; the runtime moves files with atomic `rename`
- debug XML files can be written after setting `P1_DEBUG_XML=1`; the directory can be overridden with `P1_DEBUG_XML_PATH`
- `p1.environment` switches the target host:
  - `integration` -> `https://isus.ezdrowie.gov.pl`
  - `production` -> `https://sus.ezdrowie.gov.pl`
- configuration is semantically validated on startup:
  - required password environment variables are checked
  - `wss` and `tls` files are checked for readability
  - both PKCS#12 files are opened
- `inbox`, `processing`, `done`, `invalid`, and `results` directories are already part of the configuration model, but the full directory lifecycle is used by continuous mode
- `config/config.example.yml` can be run locally without changes, or directories can be overridden through `.env`
- the simplest model is to set `P1_DATA_ROOT`, `P1_LOGS_ROOT`, and `P1_CERTIFICATES_BASE_PATH`
- if an integrator wants full control, each path can be overridden individually with `P1_INBOX_PATH`, `P1_PROCESSING_PATH`, `P1_DONE_PATH`, `P1_INVALID_PATH`, `P1_RESULTS_PATH`, and `P1_AUDIT_LOG_PATH`
- certificate passwords are read from the environment variables indicated by:
  - `certificates.wss.password_env`
  - `certificates.tls.password_env`

## Docker Compose

The repository contains two Compose variants:

- [docker-compose.yml](docker-compose.yml) - the default variant without local Ruby, with the `p1-connector` service
- [docker-compose.dev.yml](docker-compose.dev.yml) - helper services for working with local Ruby

The default [docker-compose.yml](docker-compose.yml) includes:

- `p1-connector` - a Ruby image with the application, running `watch` by default
- `redis` - ready for `Sidekiq`
- `signature-tool` - an optional local `signature-service` under the `signature` profile

In container mode, the application uses paths inside the container:

- data: `/data`
- logs: `/logs`
- certificates: `/certs`
- Redis: `redis://redis:6379/0`

Host directories mounted into the container are configured through `.env.compose`.

Preparation:

```bash
cp config/config.example.yml config/config.yml
cp .env.compose.example .env.compose
```

In `.env.compose`, set at least:

- `P1_HOST_CERTIFICATES_PATH`
- `WSS_CERT_PASSWORD`
- `TLS_CERT_PASSWORD`

Build the image:

```bash
docker compose --env-file .env.compose build p1-connector
```

Check configuration:

```bash
docker compose --env-file .env.compose run --rm -T p1-connector \
  verify --config config/config.yml
```

Process one file:

```bash
docker compose --env-file .env.compose run --rm -T p1-connector \
  run-once \
  --config config/config.yml \
  --input spec/fixtures/runtime/register_encounter_input.json \
  --output /data/manual-output.json
```

Continuous mode:

```bash
docker compose --env-file .env.compose up p1-connector
```

In a second terminal, put a file into the host data directory:

```bash
cp spec/fixtures/runtime/register_encounter_input.json var/data/inbox/task-1.json
```

Tests in the container:

```bash
docker compose --env-file .env.compose run --rm -T --entrypoint bundle p1-connector \
  exec rake test
```

If you want to run the local `signature-tool` for `register_provenance`, add the profile:

```bash
docker compose --env-file .env.compose --profile signature up p1-connector signature-tool
```

### Redis

Start only Redis for local Ruby:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

Stop it:

```bash
docker compose -f docker-compose.dev.yml down
```

Integration tests run from local Ruby assume that `redis` is started from [docker-compose.dev.yml](docker-compose.dev.yml).

The MVP supports two working modes:

1. default `docker compose` with the `p1-connector` service
2. local Ruby + `redis` started from `docker-compose.dev.yml`

## Available Commands

Main repository entrypoints:

- `bin/p1-tool` - the main runtime CLI
- `bin/p1-live-smoke` - a helper MVP deployment tool, outside the stable runtime contract

### Configuration Check

```bash
bin/p1-tool verify --config config/config.yml
```

The command:

- loads YAML configuration
- validates required fields
- checks required certificate password environment variables
- tries to open both PKCS#12 files
- confirms runtime readiness for commands that use P1 integration
- returns code `0` if configuration is valid

### Processing One File

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input /path/to/input.json \
  --output /path/to/output.json
```

The command:

- reads the input JSON file
- validates the input contract
- executes one of the supported business operations
- writes the result to the indicated file
- appends audit entries to the audit log file

Exit code:

- `0` for `success`
- `1` for `invalid` or `failure`

### Continuous Mode

A running `Redis` is required before starting continuous mode.

```bash
bin/p1-tool watch \
  --config config/config.yml \
  --sidekiq-config config/sidekiq.yml \
  --sidekiq-cron-config config/sidekiq-cron.yml
```

`watch` mode:

- bootstraps configuration once per process
- connects `Sidekiq` to the `redis.url` from application configuration
- scans `inbox` according to the `sidekiq-cron` schedule
- checks the `sidekiq-cron` schedule using the `cron_poll_interval` from `config/sidekiq.yml`
- processes files from `processing`
- moves files to `done` or `invalid`
- performs one retry for technical and transient errors

The simplest startup sequence is:

```bash
docker compose -f docker-compose.dev.yml up -d redis
bin/p1-tool watch \
  --config config/config.yml \
  --sidekiq-config config/sidekiq.yml \
  --sidekiq-cron-config config/sidekiq-cron.yml
```

### Recovery

```bash
bin/p1-tool recover --config config/config.yml
```

The command:

- loads application configuration without runtime validation
- prepares the workspace
- moves leftover files from `processing` back to `inbox`
- does not require certificate validation or P1 access

### Other CLI Commands

```bash
bin/p1-tool help
bin/p1-tool version
```

### MVP Deployment Tool

`bin/p1-live-smoke` is a helper tool for deployment and manual MVP verification.
It is not treated as a stable runtime operational contract.

## Input Contract

The minimal input file must contain:

- `task_id`
- `operation_kind`
- `payload`
- optionally `options`

Supported `operation_kind` values:

- `register_encounter`
- `register_procedure`
- `register_condition`
- `register_provenance`
- `get_resource`
- `destroy_resource`

Example:

```json
{
  "task_id": "task-1",
  "operation_kind": "register_encounter",
  "payload": {
    "patient": {
      "pesel": "75061134485",
      "first_name": "Dorota",
      "last_name": "Kalandyk"
    },
    "doctor": {
      "npwz": "3548362",
      "profession_code": "LEK",
      "name": "Dorota358 Leczniczy"
    },
    "encounter": {
      "class_code": "4",
      "start_time": "2021-09-28T12:30:00+02:00",
      "end_time": "2021-09-28T13:00:00+02:00"
    }
  }
}
```

## Execution Result

The result file contains, among other fields:

- `transport_id`
- `task_id`
- `operation_kind`
- `result_kind`
- `config_version`
- `attempt`
- `started_at`
- `finished_at`
- optional `error`
- optional `details`

Possible `result_kind` values:

- `success`
- `invalid`
- `failure`

## Audit

Audit is written to one append-only file in JSON Lines format.

The following events are written:

- `execution_started`
- `execution_finished`
- `execution_error`

## Current Version Limitations

The current version does not yet provide:

- a basic HTTP API for the runtime
- a user-facing UI

## Local Ruby Run, Step by Step

This procedure is the primary path for checking the application after preparing local configuration.
Run scenarios against the `integration` environment, with valid WSS/TLS certificates and passwords in the environment variables indicated in `config/config.yml`.
The `run-once` and `watch` scenarios using the `register_encounter_input.json` fixture perform real P1 calls and may create resources in the integration environment.

1. prepare the project:

```bash
bundle install
cp config/config.example.yml config/config.yml
cp .env.example .env
```

2. set local paths and secrets in `.env`:

```dotenv
P1_DATA_ROOT=./tmp/local/data
P1_LOGS_ROOT=./tmp/local/logs
P1_CERTIFICATES_BASE_PATH=/path/to/certificates
REDIS_URL=redis://127.0.0.1:6379/0
WSS_CERT_PASSWORD=...
TLS_CERT_PASSWORD=...
```

The `inbox`, `processing`, `done`, `invalid`, `results`, and `audit_log` directories will be created automatically.
Working directories must be on the same filesystem.

3. verify configuration:

```bash
bin/p1-tool verify --config config/config.yml
```

Expected effect:

- exit code `0`
- `Configuration OK` message

4. check one-shot `run-once` mode:

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input spec/fixtures/runtime/register_encounter_input.json \
  --output tmp/local/manual-output.json
```

Expected effect:

- exit code `0`
- `Execution finished with success` message
- `tmp/local/manual-output.json` file
- audit entries in `tmp/local/logs/audit.jsonl`

5. check the invalid input scenario:

```bash
bin/p1-tool run-once \
  --config config/config.yml \
  --input spec/fixtures/runtime/invalid_input_missing_operation_kind.json \
  --output tmp/local/manual-invalid-output.json
```

Expected effect:

- exit code `1`
- `Execution finished with invalid` message
- `tmp/local/manual-invalid-output.json` file
- the result has `result_kind` set to `invalid`

6. start Redis for `watch` mode and the integration test:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

7. start continuous `watch` mode:

```bash
bin/p1-tool watch \
  --config config/config.yml \
  --sidekiq-config config/sidekiq.yml \
  --sidekiq-cron-config config/sidekiq-cron.yml
```

Expected effect after startup:

- `Continuous mode started` message
- connection to Redis from `redis.url`

8. in a second terminal, put a file into `inbox`:

```bash
cp spec/fixtures/runtime/register_encounter_input.json tmp/local/data/inbox/task-1.json
```

After processing, check:

```bash
find tmp/local -maxdepth 4 -type f | sort
cat tmp/local/data/results/task-1.json.result.json
cat tmp/local/logs/audit.jsonl
```

Expected effect:

- the file disappears from `inbox`
- the file appears in `done/task-1.json`
- the result appears in `results/task-1.json.result.json`
- the result has `result_kind: success`
- the audit has `execution_started` and `execution_finished` events

9. check the `invalid` scenario in continuous mode:

```bash
cp spec/fixtures/runtime/invalid_input_missing_operation_kind.json tmp/local/data/inbox/task-invalid.json
```

Expected effect:

- the file appears in `invalid/task-invalid.json`
- the result appears in `results/task-invalid.json.result.json`
- the result has `result_kind: invalid`

10. stop the `watch` process with `Ctrl+C`, then optionally check `recover`:

```bash
mkdir -p tmp/local/data/processing
cp spec/fixtures/runtime/register_encounter_input.json tmp/local/data/processing/task-recover.json
bin/p1-tool recover --config config/config.yml
```

Expected effect:

- `Recovery finished` message
- `Recovered files: 1` message
- the file disappears from `processing`
- the file appears in `inbox/task-recover.json`

11. stop Redis and clean local artifacts if they are no longer needed:

```bash
docker compose -f docker-compose.dev.yml down
rm -rf tmp/local
```

`bin/p1-live-smoke` can be used as a helper during MVP deployment, but it is not the primary tester procedure.

## Tests

Default local quality gate:

```bash
bundle exec rake quality
```

Runs fast Ruby tests and RuboCop. RuboCop is run with `--cache false` so it does not depend on writing to the user's home directory.

Fast unit suite:

```bash
bundle exec rake test:unit
```

Tests generate a coverage report in `coverage/index.html`.
At this stage, coverage is an informational metric and does not block test execution with a minimum threshold.

The continuous mode integration test uses a real `redis`, but the test itself does not start the service.
If `redis` is not running, the integration test is marked as `skip`.

Start Redis:

```bash
docker compose -f docker-compose.dev.yml up -d redis
```

Integration test:

```bash
bundle exec rake test:integration
```

Full local suite:

```bash
bundle exec rake test
```

Broader local gate, also covering Java tests in `services/signature-tool`:

```bash
bundle exec rake quality:full
```

The `test:signature` task uses the project Gradle cache in `tmp/gradle` so it does not require writing to `~/.gradle`.

## CI

The repository has a GitHub Actions pipeline in `.github/workflows/ci.yml`.

The pipeline runs:

- `Ruby quality` - `bundle exec rake quality`
- `Ruby Redis integration` - `bundle exec rake test:integration` with a `redis` service
- `Signature tool` - `./gradlew test` in `services/signature-tool`

A full local run with the integration test requires:

- a running Docker
- available `docker compose`
- `redis` started from `docker-compose.dev.yml`

## Reference Files

- `config/config.example.yml` - example configuration
- `.env.example` - example environment variables
- `.env.compose.example` - example variables for the default Docker Compose setup
- `plan.md` - main description of the project direction
