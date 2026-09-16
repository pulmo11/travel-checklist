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

## Festival / Concert Update Policy

Researching new Festival / Concert schedules or changes to existing schedules, and deciding whether to register them, must not be automated by code. Only events explicitly provided and approved by the user may be added to the site data.

When handling a Festival / Concert update request:

1. Inspect the current production data and check for duplicates.
2. Apply only the entries explicitly approved by the user.
3. Confirm that the supplied date, venue, status, official URL, and other event data do not conflict with the existing structure.
4. Apply the change to a demo or development environment first.
5. QA the existing Festival / Concert features and trip-add flow.
6. Report the demo URL and a clear summary of the changes to the user.
7. Do not merge to `main` or deploy to GitHub Pages production until the user explicitly approves the production deployment.
8. Apply the change to production only after that explicit approval.
9. When deploying to production, also follow the Production Release Notes policy above.

Prohibited:

- selecting or adding new Festival / Concert events at Codex's discretion;
- adding events based only on web search results without user approval;
- publishing automated crawler results directly to production;
- automatically approving candidates based on AI judgment;
- deploying to production without explicit user approval.

The site owner always retains final authority over Festival / Concert production data.

## Rebranding Data Compatibility

Rebranding work must preserve existing user data keys and production sync behavior. Do not rename localStorage keys, Supabase fields or tables, analytics identifiers, route hashes, or stable data IDs solely to match a new brand name. User-visible product names and copy may change, but existing stored data, account sync, shared groups, and historical records must remain backward compatible.
