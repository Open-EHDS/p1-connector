# Security Policy

## Reporting Vulnerabilities

Do not report security vulnerabilities through public issues.

For a vulnerability, secret leak, certificate issue, or risk of exposing sensitive data, contact the Open-EHDS organization maintainers or the `@Open-EHDS/p1-connector-maintainers` team privately.

## Scope

This policy covers:

- the `p1-connector` application code,
- example configuration,
- the CI pipeline,
- helper tools included in this repository.

## Sensitive Data

The repository must not contain:

- secrets,
- certificates,
- private keys,
- patient data,
- production data,
- working files generated during a real P1 integration.

## Expected Actions After a Report

Maintainers should:

1. Confirm receipt of the report.
2. Assess the risk without publicly disclosing details.
3. Prepare a fix in a private or restricted channel if the nature of the vulnerability requires it.
4. After the fix, publicly describe only the information that does not increase the risk of abuse.
