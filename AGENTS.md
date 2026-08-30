# Festival Passport Project Instructions

## Production Release Notes

When deploying a user-facing change to Festival Passport production, update the public `SERVICE_UPDATES` recent-update data in `index.html` even when the user does not explicitly request it.

Apply this rule to:

- new features;
- improvements to existing features;
- bug fixes that users can notice;
- meaningful Festival or Concert recommendation changes;
- changes to account, sync, trips, packing, transport, stays, budgets, groups, or other user workflows.

Do not add a public update for:

- internal-only refactoring or code cleanup;
- tests, comments, or documentation-only changes;
- development previews, unfinished work, QA-only branches, or unshipped features;
- any change that has not been approved for and included in production.

Release-note rules:

1. Record only changes confirmed for the production deployment.
2. Use the KST deployment date in `YYYY.MM.DD` format.
3. Merge multiple deployments on the same date into one date entry without duplicate wording.
4. Describe the user-visible result, not the implementation.
5. Do not expose internal terms such as tombstone, RPC, RLS, Edge Function, migration, schema, payload, storage keys, function names, or commit SHAs.
6. Keep entries sorted newest first through the existing date-and-sequence sorting behavior.
7. Before merging to `main`, check whether a user-visible production change is missing from `SERVICE_UPDATES`.
8. Treat this check and update as a default completion requirement for production releases, without waiting for a separate user request.
9. Never include work from `dev/ui-renewal` or another unshipped branch in public release notes.
10. Never change product behavior merely to make a release-note entry fit.

Production deployment completion flow:

1. Implement the scoped change.
2. Run proportional QA and regression checks.
3. Decide whether users will notice the change.
4. Update or merge the public Recent Updates entry when applicable.
5. Verify the production diff contains no unrelated or development-preview work.
6. Merge to `main` and deploy through the existing GitHub Pages flow.
7. Run a production smoke test.
8. Confirm the matching Recent Updates entry is visible in production.

The source of truth for public release notes is the single `SERVICE_UPDATES` array in `index.html`. Do not duplicate the same public update text elsewhere unless the product explicitly requires another presentation.
