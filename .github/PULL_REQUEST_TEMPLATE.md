## What does this change?

<!-- Describe the concrete problem and the smallest solution. -->

## Area

- [ ] Universal CLI
- [ ] Core runtime
- [ ] Snapshot / secret filtering
- [ ] Agent integration
- [ ] Installer
- [ ] Documentation
- [ ] Tests / CI

## Does this keep one core?

- [ ] Yes — host integrations still converge on the universal `agysafe` CLI.
- [ ] Not applicable.

## Safety

- [ ] Does not add credential extraction.
- [ ] Does not add an unofficial AGY transport/proxy.
- [ ] Does not add dangerous permission-bypass behavior.
- [ ] Does not expose the real project workspace by default.

## Testing

- [ ] `.\tests\self-test.ps1` passes.
- [ ] New behavior has a focused test or clear manual verification.
- [ ] No real AGY quota is required by the automated test.

## Notes

<!-- Anything reviewers should pay special attention to? -->
