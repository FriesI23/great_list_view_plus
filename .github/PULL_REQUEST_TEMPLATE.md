<!-- markdownlint-disable MD041 -->
<!--
Before submitting:
- Describe the final diff and verified behavior for someone new to the change.
- Keep Summary and Test plan; remove sections and checklist items that do not apply.
- Replace placeholders and remove these comments and any generation details.
- Check an item only when completed. Explain skipped or blocked checks in Test plan.
- Keep version bumps, tags and publication within the requested release scope.
-->

## Summary

<!--
Explain the problem, what changes for users, and why in 1-3 sentences.
Add a few bullets for distinct changes or a tradeoff that matters to review.
Link related issues when applicable; use Closes #123 only if this PR resolves it.
-->

## Compatibility

<!--
Optional: describe changes to public APIs, defaults, supported platforms,
minimum Dart/Flutter versions or dependency constraints that affect consumers.
For breaking changes or deprecations, include migration steps or a short example.
Note the semantic version impact when relevant; version bumps are release work.
-->

## Test plan

<!--
List exact commands run and their results; include relevant regression coverage.
Use make check for code changes: formatting, analysis and tests for the package
and example.
For skipped, failed or blocked checks, state why and what remains unverified.
For manual checks, give the platform, steps and observed result.
Attach before/after screenshots for visible UI changes.
When package configuration, dependencies, SDK constraints, assets or release
contents change, run fvm flutter pub publish --dry-run, inspect the file list
and report any warnings.
Add results beside applicable commands below; remove commands that do not apply.
-->

- [ ] `make check`
- [ ] `fvm flutter pub publish --dry-run`

## Checklist

<!--
Keep only applicable items. Explain genuine remaining work left unchecked.
-->

- [ ] Added or updated regression tests for changed behavior.
- [ ] Updated affected public API dartdoc, READMEs and example usage.
- [ ] Added concise CHANGELOG notes for user-facing changes where needed.
- [ ] Reviewed affected public exports and SDK/dependency constraints.

## Follow-ups

<!--
Optional: list concrete remaining tasks with - [ ] and issue links if available.
Identify anything required before merging. Remove this section if none remain.
-->
