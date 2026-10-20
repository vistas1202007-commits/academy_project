# Vistas: Skill Training ERP

A Flutter + Firebase ERP for skill training institutes. It manages trainees, batches, trainers, attendance, fees, enquiries and placements in one real-time system, replacing manual registers and spreadsheets.

**Live web app:** https://vistas-erp.web.app
**Android APK:** [Download](apk/vistas-erp.apk) (allow "Install from unknown sources" when prompted)

### Demo Login

All demo accounts use the password `test123456`.

| Role | Email |
|---|---|
| Admin | `unknown@gmail.com` |
| Trainer | `user1@gmail.com` |
| Mobilizer | `user2@gmail.com` |
| Placement Officer | `user3@gmail.com` |

The demo uses sample data. Please do not enter real personal information.

## Overview

The app covers a trainee's full journey through a vocational training institute: first enquiry, registration, batch training and attendance, fee collection, and final placement. Each staff role gets its own dashboard and permissions.

## User Roles

| Role | Responsibilities |
|---|---|
| **Admin** | Full access: trainees, batches, staff, companies, placements, reports and analytics |
| **Trainer** | Views trainees in assigned batches and marks daily attendance |
| **Placement Officer** | Manages company tie-ups and tracks trainee placements |
| **Mobilizer** | Logs and follows up enquiries (leads) from prospective trainees |

## Features

- **Trainee management:** profiles with personal, guardian and training details, auto-generated Trainee IDs (`VIS-YYYY-0001`) and status tracking (Registered → Joined → Ongoing → Completed / Dropped)
- **Batches:** create batches by course, trainer and duration, and view the trainees enrolled in each
- **Attendance:** daily attendance marking and attendance history
- **Fees:** total, paid and pending amounts, a fees report, and PDF fee receipts
- **Enquiries:** log leads, track follow-ups and convert them into registered trainees
- **Placements:** company database and placement tracking for each trainee
- **Analytics:** charts and data export, plus an at-risk list that flags trainees falling behind
- **Ask Data:** answer quick questions about the data from a single screen
- **Bulk import:** add trainees in bulk from Excel sheets
- **Notifications, recycle bin and app lock:** in-app notification log, restore for deleted records, and biometric/PIN lock
- **Responsive UI:** drawer on phones, sidebar on desktop and web

## Tech Stack

- **Frontend:** Flutter (Android and Web)
- **State management:** Riverpod
- **Backend:** Firebase Authentication, Cloud Firestore, Firebase Storage, Firebase Hosting
- **Libraries:** fl_chart, pdf / printing, excel, local_auth

## Run Locally

```bash
git clone https://github.com/vistas1202007-commits/academy_project.git
cd academy_project
flutter pub get
flutter run            # Android device or emulator
flutter run -d chrome  # Web
```

The app connects to its own Firebase project. To use your own backend, create a Firebase project and run `flutterfire configure` to regenerate `lib/firebase_options.dart` and `android/app/google-services.json`, then deploy `firestore.rules`.

## Build

```bash
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
flutter build web --release   # build/web, deployed with: firebase deploy --only hosting
```

