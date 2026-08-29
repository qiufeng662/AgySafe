# Support

AgySafe is a small open-source project. The fastest way to solve most problems is to determine **which layer failed**.

## Before filing an issue

Read:

1. [Quick Start](docs/QUICKSTART.md)
2. [Troubleshooting](docs/TROUBLESHOOTING.md)
3. [FAQ](docs/FAQ.md)

Then collect:

```powershell
Get-Command agysafe
agysafe --doctor
agy --version
```

If appropriate, run one short smoke test:

```powershell
agysafe --workspace "." --json --timeout 2 "只回复 OK"
```

## Good bug reports

Please include:

- AgySafe version;
- host agent;
- AGY version;
- AgySafe status;
- sanitized JSON receipt/error;
- whether the universal CLI works independently of the host agent.

## Do not post

Never post:

- passwords;
- cookies;
- OAuth/session material;
- private keys;
- API tokens;
- sensitive project source/data;
- unsanitized private paths if they reveal confidential information.

## AI-assisted support

You can also give the receipt/error to your own coding agent or ChatGPT-like assistant and ask it to follow [the troubleshooting decision tree](docs/TROUBLESHOOTING.md).

Ask it to classify the failure before changing code.
