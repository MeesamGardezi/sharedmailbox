# SharedBox Flutter Frontend

This is the new Flutter frontend for SharedBox.

## Prerequisites

1.  **Backend**: Ensure the Node.js backend is running.
    ```bash
    cd ..
    npm start
    ```
    The backend should be available at `http://localhost:3000`.

2.  **Flutter**: Ensure Flutter SDK is installed.

## Running the App

### Web
```bash
flutter run -d chrome
```

### Windows
```bash
flutter run -d windows
```

## Features

-   **Authentication**: Login and Sign up (creates Company and User in Firestore).
-   **Inbox**: View emails from all connected accounts.
    -   Search emails.
    -   Mark as read.
    -   View HTML content.
-   **Accounts**: Manage email accounts.
    -   Connect Gmail via OAuth (opens a WebView to handle the backend flow).
    -   List and delete accounts.

## Project Structure

-   `lib/main.dart`: Entry point.
-   `lib/core/`: Shared services and models.
-   `lib/features/`: Feature-specific code (Auth, Inbox, Accounts).
