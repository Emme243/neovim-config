# Google Calendar Notifications for Neovim

A custom Neovim plugin that shows popup notifications for upcoming Google Calendar meetings. Notifications appear 2 minutes before each meeting, stay visible for 5 minutes (undismissable), and pulse with a visual effect to grab your attention.

## Features

- Polls Google Calendar every 60 seconds for upcoming events
- Live countdown that updates as the meeting approaches ("2 min" -> "1 min" -> "NOW")
- Pulsing notification with catppuccin-mocha themed highlights
- Notifications cannot be dismissed for 5 minutes (resilient to `:dismiss` calls)
- Auto-starts when Neovim launches (if already authenticated)
- Toggle on/off with `<leader>gc`

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

- In your new project, go to **APIs & Services** > **Library**
- Search for **Google Calendar API**
- Click on it and press **Enable**

### 3. Configure the OAuth Consent Screen

- Go to **APIs & Services** > **OAuth consent screen**
- Select **External** as the user type and click **Create**
- Fill in the required fields:
  - **App name**: anything (e.g., `nvim-gcal`)
  - **User support email**: your email
  - **Developer contact email**: your email
- Click **Save and Continue** through the remaining steps
- Under **Test users**, click **Add Users** and add your Google email
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

### 6. Authorize in Neovim

- Open Neovim
- Run `:GcalSetup`
- Your browser will open to Google's authorization page
- Sign in and grant calendar read-only access
- You'll see a "Success" page in the browser — close it and return to Neovim
- A confirmation notification will appear in Neovim

### 7. Verify It Works

- Run `:GcalTest` to see a fake meeting notification with the pulse effect
- Run `:GcalStart` to begin polling (this happens automatically after setup)

## Commands

| Command | Description |
|---------|-------------|
| `:GcalSetup` | Run the Google OAuth authorization flow |
| `:GcalStart` | Start polling for upcoming meetings |
| `:GcalStop` | Stop polling |
| `:GcalTest` | Show a test notification to verify visuals |

## Keybindings

| Key | Description |
|-----|-------------|
| `<leader>gc` | Toggle calendar notifications on/off |

## How It Works

- A background timer polls the Google Calendar API every 60 seconds
- When an event is found within 2 minutes of starting, a sticky notification appears
- The notification updates every 30 seconds with a live countdown
- Two highlight groups alternate every 800ms to create the pulse effect
- After 5 minutes, the notification auto-dismisses
- OAuth tokens are stored at `~/.local/share/nvim/gcal-notify/tokens.json` and refresh automatically

## Configuration

You can customize defaults by passing options to `setup()` in `lua/plugins/gcal-notify.lua`:

```lua
require("gcal-notify").setup({
  credentials_path = vim.fn.stdpath("config") .. "/.gcal-credentials.json",
  poll_interval = 60,       -- seconds between API polls
  notify_before = 120,      -- seconds before meeting to show notification
  notify_duration = 300,    -- seconds the notification stays visible
  pulse_interval = 800,     -- milliseconds between pulse toggles
  calendar_id = "primary",  -- Google Calendar ID to poll
})
```

## File Structure

```
lua/gcal-notify/
  init.lua        -- orchestrator: setup, poll timer, commands
  auth.lua        -- OAuth2 flow, token storage and refresh
  calendar.lua    -- Google Calendar API calls and event parsing
  notify.lua      -- notification display, pulse effect, countdown
lua/plugins/
  gcal-notify.lua -- lazy.nvim plugin spec
```

## Troubleshooting

- **"Not authenticated" error**: Run `:GcalSetup` to authorize
- **Browser doesn't open**: Manually visit the URL printed in the Neovim message bar
- **Token refresh fails**: Your token may have been revoked. Run `:GcalSetup` again
- **No notifications appearing**: Make sure you have an event on your Google Calendar within the next 10 minutes, and run `:GcalStart`
- **Check token status**: Run `:lua print(vim.inspect(require("gcal-notify.auth").read_tokens()))` to inspect stored tokens
