# Day 37 Developer Notes: Lichess Login Bug Fix

## What Went Wrong & Why

1. **OAuth Redirect Scheme Rejection**:
   - **Problem**: Lichess rejected authentication requests, returning:
     `Bad authorization request: exotic redirect_uri scheme not allowed (use reverse domain notation like com.example:// for custom applications)`
   - **Why**: Secure OAuth standards reject simple custom URI schemes (like `blindchess://`) to prevent "scheme hijacking" (where multiple applications register the same scheme on a single device, causing routing conflicts). Lichess now strictly enforces reverse domain notation for custom application schemes.
2. **Infinite Loader Spinner on Cancellation/Interruption**:
   - **Problem**: When a redirect failed, browser was closed, or permission was declined, the home screen's Lichess panel would spin indefinitely.
   - **Why**: The app lacked timeout handlers, lifecycle recovery hooks, or error state parsers, leaving `isAuthenticatingNotifier` permanently set to `true` with no way to recover without restarting the app.

---

## How It Was Fixed

### 1. Reverse Domain Notation Scheme Migration
We migrated our custom redirect callback URI to reverse domain notation:
- **Old redirect_uri**: `blindchess://oauth-callback`
- **New redirect_uri**: `org.blindchess.app://oauth-callback`

We updated:
- [lichess_service.dart](file:///c:/FlutterProjects/BlindChess/lib/services/lichess_service.dart) to generate requests and match incoming deep links using the new scheme.
- [AndroidManifest.xml](file:///c:/FlutterProjects/BlindChess/android/app/src/main/AndroidManifest.xml) to intercept intent filters matching `<data android:scheme="org.blindchess.app" android:host="oauth-callback" />`.

### 2. Timeout & Lifecycle Interrupt Handlers
- **2-Minute Timeout**: Added a safety timer that cancels the login animation state and surfaces a timeout error if no redirect is received within 2 minutes of launching the browser.
- **App Lifecycle Observer**: Registered `LichessService` as a `WidgetsBindingObserver`. When the app resumes from the background (meaning the user switched back from the browser), the service waits 1.5 seconds for any final deep link callbacks. If none arrive and the spinner is still active, it resets the loading state to `false` and sets a "cancelled or interrupted" error.
- **Explicit Error Parameter Check**: Captured Lichess query parameters (such as `error=access_denied` when user clicks Cancel on the consent page) and set clear user-facing messages.

### 3. Home Screen Error/Retry State
- Expanded the home screen's Lichess dashboard widget with a new Error/Retry UI layout featuring a retry button to start the flow again.

---

## Verification Results

- All 50 tests passed successfully, including new tests checking timeout release states, cancellation handler states, and query parameters.
