# Festival Passport

> A mobile-first, local-first companion for planning festival trips, coordinating shared itineraries, and preserving personal festival history.

[Live Demo](https://pulmo11.github.io/travel-checklist/) · [Judge Guide](./JUDGE_GUIDE.md) · [Demo Data](./sample-data/demo-festivals.csv)

## Demo Video

The submission video will be linked here after it is uploaded. The live demo and the English [Judge Guide](./JUDGE_GUIDE.md) are available now.

## The Problem

Festival travelers often split flights, accommodation, packing lists, exchange rates, expenses, and group schedules across notes, spreadsheets, and messaging apps. The same information is repeatedly reformatted, while active travel plans and past festival memories become difficult to review together.

## The Solution

Festival Passport brings those workflows into one responsive web application. A traveler can create a festival trip, add transport and stays, customize a packing checklist, track currencies and costs, coordinate selected group itineraries, and view active and historical records on Festival World Map.

The core experience works without an account and stores personal planning data in the current browser. Email login is optional and enables synchronization of supported personal data across devices.

## Key Features

- **Shared Trip Engine** — a common detail view for built-in and user-created festival trips.
- **Transport and stays** — personal entries plus group-code-based shared transport and accommodation.
- **Packing checklists** — trip-specific items with add, edit, delete, check, reset, and bulk-import workflows.
- **Currency tools** — selectable currencies, reference exchange rates, and saved wallet/cash amounts.
- **Trip budgets** — trip selection, expense entry, and currency-aware cost records.
- **Festival World Map** — map, timeline, year, and country views for active trips and past festival records.
- **Bulk data tools** — CSV/TSV import for trips, festivals, transport, stays, and packing; CSV/JSON archive import and export.
- **Optional cloud sync** — email-link authentication and Supabase-backed synchronization.
- **Feedback and documentation** — an in-app guide, service introduction, update history, and feedback form.

## How It Works

1. Create a trip with its festival, destination, travel dates, currency, and enabled tools.
2. Add personal transport and accommodation, or connect a group code for shared entries.
3. Prepare with a customizable packing checklist, currency holdings, and trip expenses.
4. Review current and past festival records in Festival World Map.
5. Optionally sign in by email to synchronize supported personal planning data across devices.

## Architecture

Festival Passport is a static GitHub Pages application with no build step.

- `index.html` contains the SPA views, hash routing, trip engine, local planning tools, and client-side persistence.
- `festival-records.js` and `festival-records.css` provide Festival World Map, archive import/export, filters, and record views.
- Browser `localStorage` is the primary store for unsigned users.
- Supabase provides optional email authentication, cloud synchronization, group itineraries, feedback storage, and realtime updates.
- Leaflet and OpenStreetMap render the festival map.
- Frankfurter supplies optional public reference exchange rates.
- Google Analytics 4 receives allowlisted, non-personal interaction events only on the production GitHub Pages path.

## How to Test

For a concise English walkthrough, follow [JUDGE_GUIDE.md](./JUDGE_GUIDE.md).

Quick path:

1. Open the [live demo](https://pulmo11.github.io/travel-checklist/).
2. Select **여행 (Trips)** and create or open a trip.
3. Add transport or accommodation in the trip detail view.
4. Select **짐싸기 (Packing)** and check or edit an item.
5. Open **마이 (My Page)** and import the demo CSV.
6. Open **Festival World Map** to inspect active and past records.
7. Open **여행비 정산 (Trip Budget)** to add a sample expense.

Login is not required for this core path. Use synthetic data when testing.

## Sample Data

[`sample-data/demo-festivals.csv`](./sample-data/demo-festivals.csv) contains a fictional festival trip with transport, a stay, and packing items. It follows the app's current bulk-trip import schema and contains no personal or booking information.

To import it:

1. Open **마이 (My Page)**.
2. Select **여행 데이터 가져오기 (Import Travel Data)**.
3. Upload the CSV file.
4. Select **분석 및 미리보기 (Analyze and Preview)**.
5. Review the rows, then save the selected items.
6. Open **여행 (Trips)** or **Festival World Map** to view the result.

Importing adds data to the current browser; it does not replace existing trips or checklists by default.

## Built with Codex and GPT-5.6

Codex implemented and refined the shared trip engine, bulk import workflow, responsive packing tools, real-time group itinerary synchronization, and Festival World Map. GPT-5.6 was used through Codex to inspect the evolving codebase, translate product requests into bounded implementation tasks, preserve backward compatibility, diagnose mobile interaction issues, and verify changes across responsive layouts.

Codex accelerated:

- conversion from festival-specific pages to a reusable trip engine;
- CSV/TSV parsing, validation, preview, and import flows;
- group transport and group stay synchronization;
- mobile packing-list interaction fixes;
- World Map archive, filtering, import/export, and location handling;
- accessibility, analytics instrumentation, regression checks, and GitHub Pages deployment.

The product owner made the final decisions about privacy, local-first storage, festival-specific information architecture, confirmation and recovery flows, the separation of active trips from historical records, which information may be shared with a group, and the visual direction of the service.

Festival Passport does **not** call the OpenAI API at runtime. Codex and GPT-5.6 were development tools used to build and refine the application.

## Build Week Development Timeline

- **2026-07-18** — Public release, reusable trip workflows, bulk trip and packing import, guide and feedback support, trip budgets, group synchronization, favicon, and map interaction improvements.
- **2026-07-19** — Visitor counter privacy adjustment, festival discovery and archive improvements, trip sharing and location fixes, iPad packing touch-target improvements, and serialized checklist cloud saves.
- **2026-07-20** — Preview status, service history, and clearer Festival World Map statistics labels.
- **2026-07-22** — Submission documentation, judge guide, license, and privacy-safe demo data.

The repository commit history contains the implementation record for these changes. A representative Codex session ID must be supplied separately in the Build Week submission.

## Technical Decisions

- **Local-first core:** basic planning remains usable without registration.
- **Optional synchronization:** cloud login extends the core workflow instead of blocking it.
- **Backward-compatible persistence:** existing localStorage keys and stored trip data are preserved as features evolve.
- **Shared records stay separate:** group transport and stays are not silently merged into private entries.
- **Active and historical records differ:** planned travel keeps operational detail; past records use a lighter archive structure.
- **Static deployment:** a no-build SPA keeps GitHub Pages deployment and local inspection simple.

## Privacy and Data Storage

- Without login, personal planning data is stored in the current browser's `localStorage`.
- Clearing site data or using another browser does not carry unsigned local data over automatically.
- Email login uses Supabase magic links and enables synchronization for the same account.
- Group codes are separate from account synchronization and are used to retrieve shared group transport and stays.
- Public analytics events are allowlisted and do not include names, addresses, booking numbers, notes, or expense amounts.
- Feedback is submitted to Supabase; its optional email notification recipient is configured as a server-side secret, not in public client code.
- Supabase RLS policies and setup scripts are included for deployment review. Do not place service-role keys in the client.

For feedback notification deployment, use a private server-side setting such as:

```sh
supabase secrets set RESEND_API_KEY=re_your_key FEEDBACK_NOTIFICATION_EMAIL=your-email@example.com
```

## Known Limitations

- Unsigned local data is browser-specific and can be lost if site data is cleared.
- Email delivery, cloud sync, group sharing, feedback notifications, geocoding, map tiles, and exchange rates depend on their external services and network availability.
- Imported venue names may require manual location correction when geocoding cannot identify a precise place.
- The interface is primarily Korean; this repository provides an English judge guide rather than a full translated UI.
- Festival Passport is a preview service, so some workflows and data structures may still change.

## Local Setup

No package installation or build step is required.

```sh
git clone https://github.com/pulmo11/travel-checklist.git
cd travel-checklist
python3 -m http.server 8000
```

Open `http://localhost:8000/`.

`config.js` contains the public Supabase project URL and publishable key used by the browser client. Never add a service-role key, Resend API key, or other server secret to this file.

## Deployment

GitHub Pages serves the `main` branch from the repository root. `index.html` is the entry point and all project assets use paths compatible with `/travel-checklist/`.

## License

This project is available under the [MIT License](./LICENSE).
