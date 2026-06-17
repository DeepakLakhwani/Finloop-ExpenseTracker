# Finloop - Mobile Expense Manager

A premium personal finance management application built with Flutter, Node.js, and MySQL.

## Project Structure

- `frontend/`: Flutter mobile application.
- `backend/`: Node.js Express API.
- `docs/`: Documentation and SRS.

## Getting Started

### Backend Setup

1.  Navigate to `backend/`.
2.  Run `npm install`.
3.  Configure `.env` with your MySQL credentials.
4.  Import `schema.sql` into your MySQL database.
5.  Run `node server.js` or `npm start`.

### Frontend Setup

1.  Navigate to `frontend/`.
2.  Run `flutter pub get`.
3.  Configure Firebase (requires `google-services.json` for Android and `GoogleService-Info.plist` for iOS).
4.  Run `flutter run`.

## Tech Stack

- **Mobile**: Flutter
- **Backend**: Node.js (Express)
- **Database**: MySQL
- **Auth**: Firebase Authentication
