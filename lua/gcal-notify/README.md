# Google Calendar Notifications for Neovim

A custom Neovim plugin that shows popup notifications for upcoming Google Calendar meetings. Supports **multiple Google accounts** so you can see personal, work, and other calendars all in one place. Notifications appear 2 minutes before each meeting, stay visible for 5 minutes (undismissable), and pulse with a visual effect to grab your attention.

## Features

- **Multiple Google accounts** — add as many accounts as you need (personal, work, etc.)
- Polls Google Calendar every 60 seconds for upcoming events across all accounts
- Live countdown that updates as the meeting approaches ("2 min" -> "1 min" -> "NOW")
- Pulsing notification with catppuccin-mocha themed highlights
- Notifications cannot be dismissed for 5 minutes (resilient to `:dismiss` calls)
- Auto-starts when Neovim launches (if already authenticated)
- Toggle on/off with `<leader>gc`
- **Smart deduplication** — shared meetings across accounts show a single notification with all account labels
- Account labels in notifications so you know which calendar the meeting is from

## Prerequisites

- Neovim 0.9+
- [nvim-notify](https://github.com/rcarriga/nvim-notify) (already in this config)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (already in this config)

## Setup

### 1. Create a Google Cloud Project

- Go to [Google Cloud Console](https://console.cloud.google.com/)
- Click **Select a project** at the top, then **New Project**
- Name it something like `nvim-gcal` and click **Create**

### 2. Enable the Google Calendar API

- In your new project, go to **APIs & Services** > **Enable APIs and services**
- Search for **Google Calendar API**
- Click on it and press **Enable**

### 3. Configure the OAuth Consent Screen

- Go to **APIs & Services** > **Add Credentials**
- Select **Desktop App** as the application type and click **Create**
- Fill in the required fields:
  - **App name**: anything (e.g., `nvim-gcal`)
  - **User support email**: your email
  - **Developer contact email**: your email
- Click **Save and Continue** through the remaining steps
- Under **Test users**, click **Add Users** and add **all Google emails** you plan to authorize (personal, work, etc.)
- Click **Save and Continue**, then **Back to Dashboard**

### 4. Create OAuth 2.0 Credentials

- Go to **APIs & Services** > **Credentials**
- Click **Create Credentials** > **OAuth client ID**
- Select **Desktop app** as the application type
- Name it anything (e.g., `nvim-gcal`)
- Click **Create**
- Copy the **Client ID** and **Client Secret** shown in the popup

### 5. Save Your Credentials Locally

- Create a file at `~/.config/nvim/.gcal-credentials.json` with this content:
  ```json
  {
    "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
    "client_secret": "YOUR_CLIENT_SECRET"
  }
  ```
- This file is already gitignored so it won't be committed
- **One credentials file works for all accounts** — you only need one Google Cloud project

### 6. Authorize Your First Account

- Open Neovim
- Run `:GcalAddAccount` (or `:GcalSetup`)
- Your browser will open to Google's authorization page
- Sign in with the Google account you want to add
- Grant calendar read-only access and email identification
- You'll see a "Success" page in the browser — close it and return to Neovim
- A confirmation notification will appear: `"Google Calendar authorized: you@gmail.com"`

### 7. Add More Accounts (Optional)

- Run `:GcalAddAccount` again
- This time, sign in with a **different** Google account (e.g., your work account)
- Each account is stored separately and polled independently
- Repeat for as many accounts as you need

### 8. Verify It Works

- Run `:GcalListAccounts` to see all authorized accounts
- Run `:GcalTest` to see a fake meeting notification with the pulse effect
- Run `:GcalStart` to begin polling (this happens automatically after setup)

## Commands

| Command              | Description                                              |
| -------------------- | -------------------------------------------------------- |
| `:GcalAddAccount`    | Authorize a new Google account (opens browser for OAuth) |
| `:GcalRemoveAccount` | Remove an authorized account (interactive picker)        |
| `:GcalListAccounts`  | Show all authorized Google accounts                      |
| `:GcalSetup`         | Alias for `:GcalAddAccount` (backward compatible)        |
| `:GcalStart`         | Start polling for upcoming meetings across all accounts  |
| `:GcalStop`          | Stop polling                                             |
| `:GcalTest`          | Show a test notification to verify visuals               |

## Keybindings

| Key          | Description                          |
| ------------ | ------------------------------------ |
| `<leader>gc` | Toggle calendar notifications on/off |

## How It Works

- A background timer polls the Google Calendar API every 60 seconds
- All authorized accounts are polled sequentially in each cycle
- Events are **deduplicated** by title + start time — if the same meeting appears in multiple accounts, you get one notification showing all account labels (e.g., "Upcoming Meeting (work, personal)")
- When an event is found within 2 minutes of starting, a sticky notification appears
- The notification updates every 30 seconds with a live countdown
- Two highlight groups alternate every 800ms to create the pulse effect
- After 5 minutes, the notification auto-dismisses
- Per-account errors are isolated — if one account's token expires, the others keep working

## Multiple Accounts

### How account identification works

- When you authorize an account, the plugin fetches your email via Google's userinfo API
- The email is used as the account key (e.g., `you@gmail.com`, `you@company.com`)
- Notifications show a short label from your email (the part before `@`)

### Migrating from single-account setup

If you were using the plugin before multi-account support was added:

- Your existing token is automatically migrated as a `"default"` account
- Everything keeps working — you'll see "(default)" in notification titles
- To get proper email labels, run `:GcalAddAccount` and re-authorize the same Google account
- Then remove the old entry with `:GcalRemoveAccount` → select `"default"`

### Per-account calendar IDs

By default, the plugin polls the `"primary"` calendar for every account. If you need different calendar IDs per account, configure it in setup:

```lua
require("gcal-notify").setup({
  calendar_ids = {
    ["you@gmail.com"] = "primary",
    ["you@company.com"] = "your-work-calendar-id@group.calendar.google.com",
  },
})
```

## Configuration

You can customize defaults by passing options to `setup()` in `lua/plugins/gcal-notify.lua`:

```lua
require("gcal-notify").setup({
  credentials_path = vim.fn.stdpath("config") .. "/.gcal-credentials.json",
  poll_interval = 60,       -- seconds between API polls
  notify_before = 120,      -- seconds before meeting to show notification
  notify_duration = 300,    -- seconds the notification stays visible
  pulse_interval = 800,     -- milliseconds between pulse toggles
  calendar_id = "primary",  -- default Google Calendar ID for all accounts
  calendar_ids = nil,       -- optional per-account calendar IDs (table)
})
```

## Token Storage

- Account tokens are stored at `~/.local/share/nvim/gcal-notify/accounts.json`
- File permissions are set to `0600` (owner read/write only)
- Each account has its own `access_token`, `refresh_token`, and `expiry`
- Tokens refresh automatically when they expire

## File Structure

```
lua/gcal-notify/
  init.lua        -- orchestrator: setup, multi-account poll timer, commands
  auth.lua        -- OAuth2 flow, per-account token storage and refresh
  calendar.lua    -- Google Calendar API calls and event parsing
  notify.lua      -- notification display, pulse effect, countdown
lua/plugins/
  gcal-notify.lua -- lazy.nvim plugin spec
```

## Troubleshooting

- **"Not authenticated" error**: Run `:GcalAddAccount` to authorize at least one account
- **Browser doesn't open**: Manually visit the URL printed in the Neovim message bar
- **Token refresh fails for one account**: That account is skipped with a warning; other accounts keep working. Run `:GcalAddAccount` to re-authorize the affected account
- **No notifications appearing**: Make sure you have an event on your Google Calendar within the next 10 minutes, and run `:GcalStart`
- **"Authorization already in progress"**: Wait for the current auth flow to complete before adding another account
- **Duplicate notifications**: The plugin deduplicates by meeting title + start time. Truly different meetings with identical names starting at the same time will show separately
- **Check accounts**: Run `:GcalListAccounts` to see all authorized accounts
- **Check token status**: Run `:lua print(vim.inspect(require("gcal-notify.auth").read_all_accounts()))` to inspect stored tokens
