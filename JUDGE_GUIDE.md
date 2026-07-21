# Festival Passport — Judge Guide

**Live demo:** https://pulmo11.github.io/travel-checklist/

Festival Passport is a mobile-first, local-first planner for festival travel. The core workflow can be tested without creating an account. Please use fictional data only.

## Suggested Test Flow

1. Open the live demo and review the nearest trip and readiness summary on **홈 (Home)**.
2. Select **여행 (Trips)** from the bottom navigation, then open an existing trip or select **새 여행 추가 (Add New Trip)**.
3. In a trip detail page, add a personal transport or accommodation entry. The entry is saved in the current browser.
4. Select **짐싸기 (Packing)**, choose a trip, check an item, and try adding or editing a checklist item.
5. Open **마이 (My Page)** → **여행 데이터 가져오기 (Import Travel Data)** and upload [`sample-data/demo-festivals.csv`](./sample-data/demo-festivals.csv). Analyze the preview before saving.
6. Open **Festival World Map** from the Trips page or Home quick tools. Review the map, timeline, year, country, search, and filter views.
7. Open **여행비 정산 (Trip Budget)** from Home quick tools, choose a trip, and add a fictional expense.

## Korean Menu Reference

| Korean UI | English meaning |
| --- | --- |
| 홈 | Home |
| 여행 | Trips |
| 짐싸기 | Packing |
| 환전 | Currency / Exchange |
| 마이 | My Page |
| 새 여행 추가 | Add New Trip |
| 여행 데이터 가져오기 | Import Travel Data |
| 여행비 정산 | Trip Budget |
| 사용 가이드 | User Guide |
| 서비스 소개 | About the Service |

## What Works Without Login

- Create and open trips.
- Add personal transport, stays, packing items, and trip expenses.
- Use currency tools and save local values.
- Import the demo CSV and inspect the result.
- Add and browse past festival records in Festival World Map.
- Customize the Home layout.

These changes are stored in the current browser. Clearing browser site data removes unsigned local data.

## What Requires Login or a Group Code

- **Email login:** synchronizes supported personal planning data between devices using the same account.
- **Group code:** connects shared transport and group stays for a specific trip. It is separate from email account synchronization.
- **Group editing permissions:** only users allowed by the current group ownership and membership rules see the relevant management controls.

The core judging flow does not require login, a group code, or access to private sample data.

## Demo CSV Notes

The demo file contains one fictional trip, one fictional festival, transport, accommodation, and packing items. It uses the exact current bulk-trip import headers. Import is additive by default and does not intentionally replace existing trips or checklists.

After import, open **여행 (Trips)** to find **Mountain Echo Festival Trip 2027**, then open Festival World Map to see the trip in the destination list. Precise map placement depends on external geocoding availability.
