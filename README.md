# Vistas Academy

A Flutter + Firebase ERP (Enterprise Resource Planning) application built for **Vistas Academy**, a skill training academy, to manage trainees, batches, attendance, placements, and enquiries across multiple staff roles.

## Overview

This app digitizes the day-to-day operations of a vocational training institute — from a candidate's first enquiry, through registration and batch training, to final placement — replacing manual registers and spreadsheets with a single real-time system.

## User Roles

The app supports **4 distinct roles**, each with its own dashboard and permissions:

| Role | Responsibilities |
|---|---|
| **Admin** | Full access — manages trainees, batches, trainers, companies, placements, and staff records |
| **Trainer** | Views trainees in their assigned batch(es), marks daily attendance |
| **Placement Officer** | Manages company tie-ups and tracks student placements |
| **Mobilizer** | Registers and tracks enquiries (leads) from prospective trainees |

## Features

### Trainee Management
- Add / edit / view trainee profiles (personal, guardian, and training info)
- Auto-generated Trainee ID (format: `VIS-YYYY-0001`)
- Status tracking: Registered → Joined → Ongoing → Completed / Dropped
- Fee tracking (total fee, amount paid, pending balance)

### Batch Management
- Create and manage training batches (course, trainer, duration, status)
- View all trainees enrolled in a specific batch

### Attendance
- Trainers mark daily attendance for their assigned batch
- Attendance history tracking

### Placement
- Company/employer database
- Track which trainees are placed at which companies

### Enquiry Management
- Mobilizers log new enquiries (leads)
- Follow-up status tracking
- Convert enquiries into registered trainees

### Bulk Import
- Import trainee data in bulk from Excel spreadsheets

### Reports
- Fees report across all trainees

## Tech Stack

- **Frontend:** Flutter (cross-platform — Android, iOS, Web, Windows, macOS, Linux)
- **Backend:** Firebase
    - Cloud Firestore (database)
    - Firebase Authentication (login & role-based access)

## Status

This project has been developed and delivered to the client. It is currently in an active bug-fixing and refinement phase based on tester feedback.

---
*Private repository — internal project, not for public distribution.*