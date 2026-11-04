# Google Calendar setup

The app's Calendar view (the **Calendar** tab on macOS; on iPhone, shown when the phone is turned to
landscape) can sign in to Google Calendar directly (read-only). The same iOS-type client ID works on
both platforms. Google requires
every app to have its own OAuth client ID, which you create once in Google Cloud Console. Do these
steps in order, signed in to your own Google account.

> **Don't want to do this?** Add your Google account in **System Settings → Internet Accounts** (Mac)
> or **Settings → Apps → Calendar → Calendar Accounts** (iPhone), then in the Calendar view choose
> **macOS Calendar / iPhone Calendar → Allow Calendar Access**. Your Google calendars show up through
> the Calendar app with no client ID needed.

## 1. Create a project

Go to [console.cloud.google.com](https://console.cloud.google.com), click the project picker at the
top left, choose **New Project**, name it (for example "WSPT Todo"), click **Create**, and make sure
it's selected.

## 2. Turn on the Calendar API

Go to **APIs & Services → Library**, search for **Google Calendar API**, and click **Enable**.

Direct link: <https://console.cloud.google.com/apis/library/calendar-json.googleapis.com>

## 3. Set up the consent screen

Go to **Google Auth Platform** (<https://console.cloud.google.com/auth/overview>) and click
**Get started**:

- **App name:** WSPT Todo
- **User support email:** your Gmail
- **Audience:** **External**
- **Contact email:** your Gmail
- Agree to the policy, then click **Create**

## 4. Add yourself as a test user

This is the step most often missed. Under **Audience → Test users**, click **Add users** and enter
your own Gmail address. While the app is in "Testing" mode, only accounts on this list can sign in.

## 5. Add the calendar scope (recommended)

Under **Data Access → Add or remove scopes**, tick `.../auth/calendar.readonly` and click **Update**,
then **Save**.

## 6. Create the client

Under **Clients → Create client**:

- **Application type:** **iOS**. Choose iOS, not Desktop or Web, even though this is a Mac app. The
  app's sign-in flow (`GoogleCalendarClient.swift`) sends no client secret and redirects to the
  reversed-client-ID URL scheme, which only iOS-type clients support.
- **Name:** anything you like
- **Bundle ID:** `com.douglassmurray.wspttodo`
- **Team ID:** `6KS6QV784T` (optional). Leave App Store ID blank.

Click **Create** and copy the **Client ID**. It ends in `.apps.googleusercontent.com`.

## 7. Give the client ID to the app

Either:

- **In the app:** open the Calendar tab, paste the ID into **OAuth client ID**, then click
  **Sign in with Google**. It's saved for next time.
- **In the build:** set `GoogleOAuthClientID` in `WSPTTodo/project.yml` (under `info.properties`),
  run `xcodegen generate`, and rebuild. The in-app field is then hidden.

## Troubleshooting

| Error | Cause |
|---|---|
| "Access blocked… has not completed verification" / `access_denied` | Your account isn't on the test-user list (step 4) |
| `client_secret is missing` or `redirect_uri_mismatch` | The client is Desktop or Web type; make a new **iOS** one (step 6) |
| "Google Calendar API has not been used in project…" | The API isn't enabled, or was enabled in a different project (step 2) |
| "This app isn't verified" warning | Normal for your own app: click **Advanced → Go to WSPT Todo** |
| Signed out again about a week later | Testing mode makes your sign-in expire after 7 days. Under **Audience**, click **Publish app** so it stays signed in. That's fine for personal use, and you'll keep seeing the "unverified" warning. |
