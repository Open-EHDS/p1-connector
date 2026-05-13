# Agent Work Rules

This repository contains a Ruby file-based P1 connector and a separate Java
`signature-tool` service. Treat the existing module boundaries as part of the
design, not as incidental folder structure.

## Quality Gate

- Run `bundle exec rake quality` before handing off Ruby changes.
- Run `bundle exec rake quality:full` when a change touches continuous mode,
  Redis/Sidekiq behavior, Docker/Compose setup, or `services/signature-tool`.
- If `quality:full` cannot be run because Redis, Docker, Java, or network access
  is unavailable, state that explicitly in the handoff and include the command
  that should be run next.
- Do not lower RuboCop, test, or coverage expectations just to make a change pass.
  Prefer small refactors or a clearly justified local exclusion.

## Responsibility Boundaries

- Keep runtime orchestration in `lib/p1_tool/runtime` and `lib/p1_tool/jobs`.
- Keep operation-level business flow in `lib/p1_tool/application/operations`.
- Keep payload validation in `lib/p1_tool/application/contracts`.
- Keep XML/data mapping in `lib/p1_tool/application/builders`.
- Keep external HTTP/certificate/token details in `lib/p1_tool/gateways`.
- Keep filesystem and audit concerns in `lib/p1_tool/adapters`.
- Keep XAdES signing service changes isolated under `services/signature-tool`
  unless the Ruby client contract also needs to change.

## Change Discipline

- Prefer existing patterns over introducing new frameworks or abstractions.
- Keep changes narrow. Do not combine unrelated cleanup with behavior changes.
- Avoid duplicating P1/FHIR mapping logic. If a section appears in multiple XML
  builders, consider a shared helper before adding another copy.
- Keep operation contracts stable unless the input/output JSON shape is being
  intentionally changed and documented.
- Preserve idempotent file-processing behavior: atomic moves, terminal result
  files, audit events, and retry semantics are part of the runtime contract.

## Documentation

- Update `README.md` when commands, configuration, runtime behavior, Docker
  usage, quality gates, or operator workflows change.
- Update `docs/demo` examples when operation payloads or result shapes change.
- Update `config/config.example.yml`, `.env.example`, or `.env.compose.example`
  when configuration or environment variables change.
- Keep documentation practical and executable. Prefer commands that can be copied
  and run locally.

## Tests

- Add or update focused tests with behavior changes.
- For payload validation changes, cover both accepted input and rejected input.
- For runtime changes, cover result files, file movement, audit events, and retry
  behavior where relevant.
- For gateway/client changes, cover response parsing and error classification.
- For `signature-tool`, run or update Gradle tests under `services/signature-tool`.

## live-smoke

- Treat `bin/p1-live-smoke` and `lib/p1_tool/application/live_smoke_runner.rb` as
  MVP deployment/development tooling, not as core runtime architecture.
- Keep `live-smoke` useful for validating real deployment assumptions, but avoid
  making normal runtime code depend on it.
- Do not over-refactor `live-smoke` only for style metrics. Improve it when it
  blocks MVP validation, hides operational risk, or its behavior changes.
- Document `live-smoke` changes as operator/deployment workflow changes.

## Secrets and Local State

- Do not commit real certificates, `.env`, `.env.compose`, `config/config.yml`,
  `var`, `coverage`, or local Gradle/Ruby caches.
- Keep certificate passwords and P1 credentials in environment variables or local
  ignored files only.
- Be careful with generated XML and audit logs; they may contain operational or
  patient-related data.
