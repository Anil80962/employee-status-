# Fluxgen Status — Flutter Mobile App

Native mobile port of the Fluxgen Operations Team Portal (originally at
https://github.com/Anil80962/employee-status-). Talks to the same Google
Apps Script backend that the web portal uses — employees, statuses,
sites, inventory and users live in the same Google Sheet.

## Features

- Login with session persistence (super-admin `admin / admin123`
  + users from the `getUsers` endpoint)
- Role-gated navigation (`admin`, `manager`, `user`)
- Home with today's status + team summary
- Update Status (status grid, site autocomplete, work type, scope)
- Team Today (grouped by Assigned / Office / WFH / Leave / Available)
- Weekly Overview grid
- Team Overview with efficiency calculation
- Download Reports (Employee / Site / Work Type) with CSV share
- Manage Employees CRUD (admin)
- Manage Users CRUD (admin)
- Inventory: add/edit/delete, transactions, serial numbers,
  barcode scan (mobile_scanner)
- Customer Service Report with signature pad + PDF print/share

## Backend

All API calls hit the same Apps Script web app the portal uses —
see `lib/config.dart` if you ever move it. The endpoints match
`google_apps_script.js` actions (`submitStatus`, `getStatus`,
`getStatusRange`, `getInventory`, `invTransaction`, etc.).

## Run

```
flutter --version         # >=3.19
flutter create .          # generates missing android/ios plumbing
flutter pub get
flutter run               # on an attached device / emulator
```

If `flutter create .` is skipped, ensure `android/build.gradle`,
`android/settings.gradle`, `android/app/build.gradle` and the iOS
Runner project files exist. The provided `AndroidManifest.xml` and
`Info.plist` already include camera permissions for the barcode
scanner.

## Config

- `lib/config.dart` — Apps Script URL, super-admin creds, status enum
- `lib/theme.dart` — Fluxgen palette
- `pubspec.yaml` — dependencies

## Notes

- The web portal POSTs to the Apps Script using `text/plain` to avoid
  the CORS preflight. On mobile we don't need that trick so
  `ApiService._post` uses `application/x-www-form-urlencoded`.
- Make sure the Apps Script web app is deployed with "Anyone" access
  (same as the portal), otherwise POSTs will 302 and fail.
