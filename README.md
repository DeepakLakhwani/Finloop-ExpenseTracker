# Finloop - Smart Expense Tracker

Finloop is a premium, secure, and modern personal finance management application built with Flutter and Firebase. It empowers users to track their daily transactions, split expenses with groups, secure their financial records using passcode/biometric authentication, and analyze their spending habits with interactive charts.

---

## 🚀 Key Features

- **Transaction Management**: Easily track income, expenses, and transfers. View summaries on daily, weekly, or monthly timelines.
- **Interactive Analytics**: Clear visual breakdowns of your spending habits using interactive charts.
- **Multi-Account Tracking**: Manage balances across multiple accounts (Cash, Bank, Cards, Savings) with dedicated activity histories.
- **Group Expense Splitting**: Create groups, add shared expenses, track balances, and settle debts with other group members.
- **Security & Privacy**: Protect your financial data using secure PIN/Passcode lock and biometric login.
- **Data Portability**: Export transactions and account histories to Excel/CSV worksheets, and import existing data templates.
- **Direct Feedback**: Send questions, feedback, or bug reports with local screenshot attachment support directly to the support team.
- **Customization**: Dark and Light themes with dynamic custom colors.

---

## 🛠️ Tech Stack & Architecture

- **Mobile Client**: Flutter (Dart)
- **State Management**: Provider (multi-provider architecture)
- **Database & Auth**: Cloud Firestore (NoSQL database) & Firebase Authentication
- **Cloud Functions**: Node.js Firebase Functions for routing feedback emails
- **Storage**: Firebase Storage (configured for feedback attachments)

---

## 📁 Repository Structure

```text
Finloop/
├── frontend/          # Main Flutter mobile application
├── functions/         # Firebase Cloud Functions (Node.js) for backend actions
├── storage.rules      # Firebase Storage security rules
└── firebase.json      # Firebase configuration file
```

---

## 🏁 Getting Started

### Prerequisites

Make sure you have the following installed on your machine:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
- [Dart SDK](https://dart.dev/get-started)
- [Git](https://git-scm.com/)

---

### Setup Instructions

1. **Clone the Repository**
   ```bash
   git clone https://github.com/DeepakLakhwani/Finloop-ExpenseTracker.git
   cd Finloop-ExpenseTracker
   ```

2. **Firebase Project Setup**
   - Create a project in the [Firebase Console](https://console.firebase.google.com/).
   - Add an Android/iOS app to your project.
   - Download the client configuration files and place them in:
     - Android: `frontend/android/app/google-services.json`
     - iOS: `frontend/ios/Runner/GoogleService-Info.plist`
   - Enable **Firebase Authentication**, **Cloud Firestore**, and **Firebase Storage** in the console.

3. **Install Dependencies**
   Navigate to the frontend folder and pull the Flutter packages:
   ```bash
   cd frontend
   flutter pub get
   ```

4. **Run the Application**
   Run the development build on an emulator or physical device:
   ```bash
   flutter run
   ```

---

## 🔒 License

This project is built for personal expense tracking. Feel free to clone, customize, and adapt it to your financial tracking needs.
