local curl = require("plenary.curl")

local M = {}

local API_BASE = "https://www.googleapis.com/calendar/v3/calendars"

--- Parse an ISO 8601 timestamp to epoch seconds.
--- Handles formats: "2026-03-25T10:30:00-05:00" and "2026-03-25T15:30:00Z"
function M.parse_iso8601(str)
	if not str then
		return nil
	end

	local year, month, day, hour, min, sec = str:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if not year then
		return nil
	end

	-- Parse timezone offset
	local tz_sign, tz_hour, tz_min = str:match("([+-])(%d%d):(%d%d)$")
	local offset_seconds = 0

	if tz_sign then
		offset_seconds = (tonumber(tz_hour) * 3600 + tonumber(tz_min) * 60)
		if tz_sign == "+" then
			offset_seconds = -offset_seconds
		end
	elseif str:match("Z$") then
		offset_seconds = 0
	end

	-- Convert to epoch using os.time (interprets as local time)
	local utc_time = os.time({
		year = tonumber(year),
		month = tonumber(month),
		day = tonumber(day),
		hour = tonumber(hour),
		min = tonumber(min),
		sec = tonumber(sec),
	}) + offset_seconds

	-- Adjust for local timezone: os.time assumes local, but we computed UTC
	local local_time = os.time()
	local utc_now = os.time(os.date("!*t", local_time))
	local tz_diff = local_time - utc_now

	return utc_time + tz_diff
end

--- Compute seconds from now until a given ISO 8601 timestamp.
function M.seconds_until(iso_timestamp)
	local epoch = M.parse_iso8601(iso_timestamp)
	if not epoch then
		return nil
	end
	return epoch - os.time()
end

--- Parse events from Google Calendar API response body.
--- @param body string JSON response body
--- @param account_email string|nil The account email for tagging events
function M.parse_events(body, account_email)
	local ok, data = pcall(vim.fn.json_decode, body)
	if not ok or not data.items then
		return {}
	end

	local events = {}
	for _, item in ipairs(data.items) do
		-- Skip all-day events (they have start.date, not start.dateTime)
		if item.start and item.start.dateTime then
			local start_time = item.start.dateTime
			local end_time = item["end"] and item["end"].dateTime or nil
			local start_epoch = M.parse_iso8601(start_time)

			table.insert(events, {
				id = item.id,
				summary = item.summary or "(No title)",
				start_time = start_time,
				end_time = end_time,
				start_epoch = start_epoch,
				html_link = item.htmlLink,
				account = account_email,
				dedup_key = (item.summary or "") .. "|" .. tostring(start_epoch or ""),
			})
		end
	end

	return events
end

--- Format epoch time as "HH:MM AM/PM".
function M.format_time(iso_timestamp)
	local epoch = M.parse_iso8601(iso_timestamp)
	if not epoch then
		return ""
	end
	return os.date("%I:%M %p", epoch)
end

--- Fetch upcoming events from Google Calendar.
--- @param access_token string
--- @param calendar_id string
--- @param minutes_ahead number
--- @param account_email string|nil The account email for tagging events
--- @param callback function(events, err)
function M.fetch_upcoming(access_token, calendar_id, minutes_ahead, account_email, callback)
	local now = os.time()
	local time_min = os.date("!%Y-%m-%dT%H:%M:%SZ", now)
	local time_max = os.date("!%Y-%m-%dT%H:%M:%SZ", now + (minutes_ahead * 60))

	local url = string.format(
		"%s/%s/events?timeMin=%s&timeMax=%s&singleEvents=true&orderBy=startTime&maxResults=10",
		API_BASE,
		vim.uri_encode(calendar_id, "rfc2396"),
		vim.uri_encode(time_min, "rfc2396"),
		vim.uri_encode(time_max, "rfc2396")
	)

	curl.get(url, {
		headers = { ["Authorization"] = "Bearer " .. access_token },
		callback = vim.schedule_wrap(function(response)
			if response.status ~= 200 then
				callback(nil, "Calendar API error (HTTP " .. response.status .. ")")
				return
			end
			local events = M.parse_events(response.body, account_email)
			callback(events)
		end),
	})
end

return M
