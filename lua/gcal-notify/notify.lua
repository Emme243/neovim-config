local calendar = require("gcal-notify.calendar")

local M = {}

local pulse_timers = {} -- win_id -> timer
local active_notifications = {} -- dedup_key -> { notif_id, dismiss_at }

local config = {
	notify_duration = 300,
	pulse_interval = 800,
}

function M.setup(opts)
	config = vim.tbl_extend("force", config, opts or {})
	M.setup_highlights()
end

function M.setup_highlights()
	-- Pulse "on" state: vibrant (catppuccin-mocha red/pink)
	vim.api.nvim_set_hl(0, "GcalNotifyBorderOn", { fg = "#f38ba8" })
	vim.api.nvim_set_hl(0, "GcalNotifyBodyOn", { bg = "#302030" })
	vim.api.nvim_set_hl(0, "GcalNotifyTitleOn", { fg = "#f38ba8", bold = true })
	vim.api.nvim_set_hl(0, "GcalNotifyIconOn", { fg = "#f38ba8" })

	-- Pulse "off" state: subdued
	vim.api.nvim_set_hl(0, "GcalNotifyBorderOff", { fg = "#f5c2e7" })
	vim.api.nvim_set_hl(0, "GcalNotifyBodyOff", { bg = "#1e1e2e" })
	vim.api.nvim_set_hl(0, "GcalNotifyTitleOff", { fg = "#f5c2e7", bold = true })
	vim.api.nvim_set_hl(0, "GcalNotifyIconOff", { fg = "#f5c2e7" })
end

local function winhighlight_on()
	return table.concat({
		"NotifyWARNBorder:GcalNotifyBorderOn",
		"NotifyWARNBody:GcalNotifyBodyOn",
		"NotifyWARNTitle:GcalNotifyTitleOn",
		"NotifyWARNIcon:GcalNotifyIconOn",
	}, ",")
end

local function winhighlight_off()
	return table.concat({
		"NotifyWARNBorder:GcalNotifyBorderOff",
		"NotifyWARNBody:GcalNotifyBodyOff",
		"NotifyWARNTitle:GcalNotifyTitleOff",
		"NotifyWARNIcon:GcalNotifyIconOff",
	}, ",")
end

function M.start_pulse(win)
	if pulse_timers[win] then
		return
	end

	local timer = vim.loop.new_timer()
	local is_on = true

	timer:start(0, config.pulse_interval, vim.schedule_wrap(function()
		if not vim.api.nvim_win_is_valid(win) then
			M.stop_pulse(win)
			return
		end

		local hl = is_on and winhighlight_on() or winhighlight_off()
		vim.api.nvim_set_option_value("winhighlight", hl, { win = win })
		is_on = not is_on
	end))

	pulse_timers[win] = timer
end

function M.stop_pulse(win)
	local timer = pulse_timers[win]
	if timer then
		if not timer:is_closing() then
			timer:stop()
			timer:close()
		end
		pulse_timers[win] = nil
	end
end

function M.stop_all_pulses()
	for win, _ in pairs(pulse_timers) do
		M.stop_pulse(win)
	end
end

--- Extract short account label from email (part before @).
local function account_label(email)
	if not email then
		return nil
	end
	return email:match("^([^@]+)") or email
end

--- Build notification title with account label(s).
local function build_title(event)
	local accounts = event.accounts or (event.account and { event.account } or nil)
	if not accounts or #accounts == 0 then
		return "Upcoming Meeting"
	end

	local labels = {}
	for _, acct in ipairs(accounts) do
		table.insert(labels, account_label(acct))
	end
	return "Upcoming Meeting (" .. table.concat(labels, ", ") .. ")"
end

--- Build notification message lines for an event.
local function build_message(event, seconds_remaining)
	local time_text
	if seconds_remaining <= 0 then
		time_text = "Meeting starting NOW"
	elseif seconds_remaining <= 60 then
		time_text = "Meeting in less than 1 min"
	else
		local mins = math.ceil(seconds_remaining / 60)
		time_text = string.format("Meeting in %d min", mins)
	end

	local start_str = calendar.format_time(event.start_time)
	local end_str = event.end_time and calendar.format_time(event.end_time) or ""
	local time_range = end_str ~= "" and (start_str .. " - " .. end_str) or start_str

	return string.format("%s\n%s\n%s", time_text, event.summary, time_range)
end

--- Show or update a meeting notification with pulse effect.
function M.show_meeting(event, seconds_remaining)
	local notify = require("notify")
	local key = event.dedup_key or event.id
	local dismiss_at = os.time() + config.notify_duration
	local existing = active_notifications[key]

	if existing then
		dismiss_at = existing.dismiss_at
	end

	local message = build_message(event, seconds_remaining)
	local title = build_title(event)

	local remaining_ms = math.max((dismiss_at - os.time()) * 1000, 1000)
	local opts = {
		title = title,
		icon = "⏰",
		timeout = remaining_ms,
		on_open = function(win)
			vim.api.nvim_win_set_config(win, { zindex = 200 })
			M.start_pulse(win)
		end,
		on_close = function(win)
			M.stop_pulse(win)
		end,
	}

	-- Replace existing notification for the same event
	if existing and existing.notif_id then
		opts.replace = existing.notif_id
	end

	local notif = notify(message, "warn", opts)

	active_notifications[key] = {
		notif_id = notif,
		dismiss_at = dismiss_at,
	}
end

--- Show a test notification to verify the pulse effect.
function M.show_test()
	local fake_event = {
		id = "test-" .. os.time(),
		summary = "Test Meeting - Calendar Integration",
		start_time = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + 120),
		end_time = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + 3720),
		account = "test@example.com",
		dedup_key = "test-" .. os.time(),
	}
	M.show_meeting(fake_event, 120)
end

--- Check if an event already has an active notification.
function M.is_active(dedup_key)
	local existing = active_notifications[dedup_key]
	if not existing then
		return false
	end
	-- Clean up expired entries
	if os.time() >= existing.dismiss_at then
		active_notifications[dedup_key] = nil
		return false
	end
	return true
end

--- Clean up expired notification entries.
function M.cleanup()
	local now = os.time()
	for key, data in pairs(active_notifications) do
		if now >= data.dismiss_at then
			active_notifications[key] = nil
		end
	end
end

return M
