# Security

## Architecture

AgySafe is local-first and uses the official `agy` CLI.

Agent-specific integrations do not receive or handle Google credentials. They only invoke the local `agysafe` command.

```text
Agent -> agysafe -> isolated workspace -> official agy
```

## Isolation

Project review/edit tasks use an isolated filtered project copy under:

```text
%USERPROFILE%\AgySafeWorkspaces
```

The installer attempts to register only this AgySafe-managed root in AGY `trustedWorkspaces`. It does not add users' real project directories.

Before changing an existing AGY settings file, the installer creates a timestamped backup.

## Secret filtering

Examples of excluded data:

- `.env` and `.env.*` except common example/template files;
- private-key files;
- credential/secrets files;
- common local databases;
- `.git`, dependencies, caches and virtual environments;
- files larger than the snapshot limit;
- high-confidence private-key, OpenAI-style key, GitHub token, Google API key and AWS access-key patterns.

Common secret-like environment variables inherited from the host agent are also removed before AGY is launched. Proxy environment variables are retained.

## Agent integrations

AgySafe uses the smallest practical host integration:

- slash/custom command where the host has a stable format;
- persistent instruction file where officially supported;
- otherwise the universal local `agysafe` CLI.

Host adapters must not reimplement authentication, workspace isolation, model routing, or AGY transport.

## Permission policy

AgySafe:

- uses official AGY sandbox mode;
- does not add dangerous permission-bypass flags;
- instructs delegated project tasks not to use shell/terminal tools;
- does not automatically copy isolated edit results into the real project.

## Limitations

Secret filtering cannot identify every possible credential.

AgySafe cannot guarantee service availability, account eligibility, region eligibility, quota, or zero account-policy risk. Those remain controlled by Google/Antigravity and the user's own environment.
