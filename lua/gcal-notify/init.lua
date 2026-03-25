local auth = require("gcal-notify.auth")
local calendar = require("gcal-notify.calendar")
local notifier = require("gcal-notify.notify")

local M = {}

local defaults = {
	credentials_path = vim.fn.stdpath("config") .. "/.gcal-credentials.json",
	poll_interval = 60, -- seconds between API polls
	notify_before = 120, -- seconds before meeting to notify (2 min)
	notify_duration = 300, -- seconds notification stays visible (5 min)
	pulse_interval = 800, -- ms between pulse toggles
	calendar_id = "primary",
}

local config = {}
local poll_timer = nil
local countdown_timer = nil
local is_running = false
local pending_events = {} -- events awaiting countdown updates

function M.setup(opts)
	config = vim.tbl_extend("force", defaults, opts or {})

	auth.setup({ credentials_path = config.credentials_path })
	notifier.setup({
		notify_duration = config.notify_duration,
		pulse_interval = config.pulse_interval,
	})

	-- Register commands
	vim.api.nvim_create_user_command("GcalSetup", function()
		auth.start_auth_flow()
	end, { desc = "Authorize Google Calendar access" })

	vim.api.nvim_create_user_command("GcalStart", function()
		M.start()
	end, { desc = "Start Google Calendar polling" })

	vim.api.nvim_create_user_command("GcalStop", function()
		M.stop()
	end, { desc = "Stop Google Calendar polling" })

	vim.api.nvim_create_user_command("GcalTest", function()
		notifier.show_test()
	end, { desc = "Show a test meeting notification" })

	-- Keybinding
	vim.keymap.set("n", "<leader>gc", function()
		M.toggle()
	end, { desc = "Toggle GCal Notifications" })

	-- Clean up on exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			M.stop()
		end,
	})

	-- Auto-start if authenticated
	if auth.is_authenticated() then
		-- Defer start to ensure everything is loaded
		vim.defer_fn(function()
			M.start()
		end, 2000)
	end
end

function M.start()
	if is_running then
		vim.notify("GCal notifications already running", vim.log.levels.INFO, { title = "GCal Notify" })
		return
	end

	if not auth.is_authenticated() then
		vim.notify("Not authenticated. Run :GcalSetup first.", vim.log.levels.WARN, { title = "GCal Notify" })
		return
	end

	is_running = true

	-- Poll immediately, then on interval
	M.poll()

	poll_timer = vim.loop.new_timer()
	poll_timer:start(config.poll_interval * 1000, config.poll_interval * 1000, vim.schedule_wrap(function()
		M.poll()
	end))

	-- Countdown timer updates active notifications every 30 seconds
	countdown_timer = vim.loop.new_timer()
	countdown_timer:start(30000, 30000, vim.schedule_wrap(function()
		M._update_countdowns()
	end))

	vim.notify("GCal notifications started", vim.log.levels.INFO, { title = "GCal Notify" })
end

function M.stop()
	is_running = false

	if poll_timer then
		if not poll_timer:is_closing() then
			poll_timer:stop()
			poll_timer:close()
		end
		poll_timer = nil
	end

	if countdown_timer then
		if not countdown_timer:is_closing() then
			countdown_timer:stop()
			countdown_timer:close()
		end
		countdown_timer = nil
	end

	notifier.stop_all_pulses()
	notifier.cleanup()
	pending_events = {}

	vim.notify("GCal notifications stopped", vim.log.levels.INFO, { title = "GCal Notify" })
end

function M.toggle()
	if is_running then
		M.stop()
	else
		M.start()
	end
end

function M.poll()
	if not is_running then
		return
	end

	auth.get_access_token(function(token, err)
		if not token then
			vim.notify(err or "Failed to get access token", vim.log.levels.ERROR, { title = "GCal Notify" })
			return
		end

		-- Fetch events for the next 10 minutes
		calendar.fetch_upcoming(token, config.calendar_id, 10, function(events, fetch_err)
			if not events then
				vim.notify(fetch_err or "Failed to fetch events", vim.log.levels.ERROR, { title = "GCal Notify" })
				return
			end

			for _, event in ipairs(events) do
				local seconds = calendar.seconds_until(event.start_time)
				if seconds and seconds <= config.notify_before and seconds > -config.notify_duration then
					if not notifier.is_active(event.id) then
						notifier.show_meeting(event, seconds)
					end
					-- Track for countdown updates
					pending_events[event.id] = event
				end
			end

			notifier.cleanup()
		end)
	end)
end

function M._update_countdowns()
	if not is_running then
		return
	end

	for event_id, event in pairs(pending_events) do
		if notifier.is_active(event_id) then
			local seconds = calendar.seconds_until(event.start_time)
			if seconds then
				notifier.show_meeting(event, seconds)
			end
		else
			pending_events[event_id] = nil
		end
	end
end

return M
