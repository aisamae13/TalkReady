# TalkReady

> **TalkReady** is a specialized capstone project designed to train and empower aspiring call center professionals in the Philippines. 

The system leverages a mobile application alongside a serverless backend infrastructure to deliver interactive training, modules, and performance evaluations.

---

## 📁 Repository Structure

*   `talkready_mobile/` – The core mobile application frontend.
*   `functions/` – Serverless backend logic (Firebase Cloud Functions).
*   `firebase.json` / `.firebaserc` – Firebase platform configuration files.

---

## Getting Started

To get a local copy of this project up and running, follow these step-by-step instructions for both the backend and frontend components.

### Prerequisites

Before setting up the project, make sure you have the following installed:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel)
*   [Node.js](https://nodejs.org/) (v18 or higher recommended for Firebase Functions)
*   [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
*   An IDE like Visual Studio Code or Android Studio

---

## 🛠️ Backend Setup (Firebase)

The backend relies on Firebase Services and Cloud Functions. Follow these steps to configure your environment.

### 1. Initialize and Authenticate CLI
Open your terminal at the root directory of the repository and log into your Firebase account:
```bash
firebase login
```

### 2. Select Your Active Project
Link your local environment to your Firebase project instance:
```bash
firebase use --add
```

### 3. Install Dependencies
Navigate into the `functions` folder and install the required Node.js packages:
```bash
cd functions
npm install
```

### 4. Local Emulation (Optional)
To test your cloud functions locally without deploying them to production:
```bash
firebase emulators:start
```

### 5. Deployment
When you are ready to publish changes to the live backend:
```bash
firebase deploy --only functions
```

---

## Mobile App Setup (Flutter)

Follow these steps to configure, build, and run the `talkready_mobile` application.

### 1. Navigate to the Mobile Directory
```bash
cd talkready_mobile
```

### 2. Fetch Package Dependencies
Download all required Flutter and Dart plugins specified in the `pubspec.yaml` file:
```bash
flutter pub get
```

### 3. Configure Platforms (Android/iOS)
Ensure your target device or emulator is active. You can list available devices using:
```bash
flutter devices
```

### 4. Run the Application
Launch the app in debug mode on your connected device:
```bash
flutter run
```

---

## Security & Environment Variables

*   **Production Keys:** Never commit sensitive production credentials, API keys, or Firebase configuration objects directly to this repository. Refer to `SECURITY.md` for our vulnerability disclosure policies.
*   **Gitignore:** Local IDE settings (`.vscode/`), dependencies (`node_modules/`, `.dart_tool/`), and generated build files are ignored automatically via the root `.gitignore`.
