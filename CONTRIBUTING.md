# Contributing

Thank you for your interest in contributing to `p1-connector`.

## Working Model

- The main and protected repository branch is `main`.
- We do not use a permanent `develop` branch.
- Changes are merged into `main` through pull requests.
- The default merge strategy is squash merge.
- Working branches are deleted automatically after merge.

## Pull Requests

1. Create a branch with a short, descriptive name.
2. Prepare a change with a reasonably coherent scope.
3. Run the relevant tests.
4. Open a PR to `main` and fill in the template.
5. Wait for the required maintainer review and CODEOWNERS review.

Minimum PR standard:

- 1 approval.
- CODEOWNERS review.
- Comments resolved before merge.
- Green CI when the repository has an active stable workflow for the given scope.

## Permissions

Repository access is managed through GitHub organization teams, not through direct collaborators. For this repository, the primary maintaining team is `@Open-EHDS/p1-connector-maintainers`.

## Tests

Basic local quality suite:

```bash
bundle exec rake quality
```

Integration tests with Redis:

```bash
INTEGRATION_REDIS_URL=redis://127.0.0.1:6379/0 REQUIRE_REDIS_INTEGRATION=1 bundle exec rake test:integration
```

Signature tool tests:

```bash
cd services/signature-tool
./gradlew test
```

## Secrets and Sensitive Data

Do not commit:

- secrets,
- certificates,
- patient data,
- production environment data,
- generated working files from P1 integration.

If a secret or sensitive data is accidentally committed to the repository, do not fix it only by removing the file in a later commit. Report the incident to the maintainers so rotation and history cleanup can be performed if needed.
