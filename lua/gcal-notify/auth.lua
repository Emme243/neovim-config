local curl = require("plenary.curl")

local M = {}

local config = {}
local data_dir = vim.fn.stdpath("data") .. "/gcal-notify"
local accounts_path = data_dir .. "/accounts.json"
local legacy_tokens_path = data_dir .. "/tokens.json"

local GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
local GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
local USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"
local REDIRECT_PORT = 8089
local REDIRECT_URI = "http://localhost:" .. REDIRECT_PORT
local SCOPE = "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/userinfo.email"

local auth_in_progress = false

function M.setup(opts)
	config = opts or {}
end

function M.read_credentials()
	local path = config.credentials_path
	if not path or vim.fn.filereadable(path) == 0 then
		return nil, "Credentials file not found: " .. (path or "nil")
	end
	local content = vim.fn.readfile(path)
	local ok, creds = pcall(vim.fn.json_decode, table.concat(content, "\n"))
	if not ok or not creds.client_id or not creds.client_secret then
		return nil, "Invalid credentials file. Must contain client_id and client_secret."
	end
	return creds
end

--- Read all accounts from accounts.json. Triggers legacy migration if needed.
function M.read_all_accounts()
	if vim.fn.filereadable(accounts_path) == 1 then
		local content = vim.fn.readfile(accounts_path)
		local ok, accounts = pcall(vim.fn.json_decode, table.concat(content, "\n"))
		if ok and type(accounts) == "table" then
			return accounts
		end
	end

	-- Try legacy migration
	if vim.fn.filereadable(legacy_tokens_path) == 1 then
		return M._migrate_legacy()
	end

	return {}
end

--- Write full accounts table to accounts.json.
function M.write_all_accounts(accounts)
	vim.fn.mkdir(data_dir, "p")
	local json = vim.fn.json_encode(accounts)
	local fd = vim.loop.fs_open(accounts_path, "w", 384) -- 0600
	if fd then
		vim.loop.fs_write(fd, json)
		vim.loop.fs_close(fd)
	end
end

--- Write tokens for a single account (read-modify-write).
function M.write_account_tokens(email, tokens)
	local accounts = M.read_all_accounts()
	accounts[email] = tokens
	M.write_all_accounts(accounts)
end

--- Remove an account by email.
function M.remove_account(email)
	local accounts = M.read_all_accounts()
	if not accounts[email] then
		return false
	end
	accounts[email] = nil
	M.write_all_accounts(accounts)
	return true
end

--- Get list of account emails.
function M.get_account_list()
	local accounts = M.read_all_accounts()
	local list = {}
	for email, _ in pairs(accounts) do
		table.insert(list, email)
	end
	table.sort(list)
	return list
end

--- Check if at least one account is authenticated.
function M.is_authenticated()
	local accounts = M.read_all_accounts()
	for _, tokens in pairs(accounts) do
		if tokens.refresh_token then
			return true
		end
	end
	return false
end

--- Get access token for a specific account.
function M.get_access_token(email, callback)
	local accounts = M.read_all_accounts()
	local tokens = accounts[email]

	if not tokens or not tokens.refresh_token then
		callback(nil, "Account not authenticated: " .. email)
		return
	end

	-- Check if token is still valid (with 60s buffer)
	if tokens.access_token and tokens.expiry and os.time() < (tokens.expiry - 60) then
		callback(tokens.access_token)
		return
	end

	-- Refresh the token
	local creds, err = M.read_credentials()
	if not creds then
		callback(nil, err)
		return
	end

	curl.post(GOOGLE_TOKEN_URL, {
		body = vim.fn.json_encode({
			client_id = creds.client_id,
			client_secret = creds.client_secret,
			refresh_token = tokens.refresh_token,
			grant_type = "refresh_token",
		}),
		headers = { ["Content-Type"] = "application/json" },
		callback = vim.schedule_wrap(function(response)
			if response.status ~= 200 then
				callback(nil, "Token refresh failed for " .. email .. " (HTTP " .. response.status .. ")")
				return
			end
			local ok, data = pcall(vim.fn.json_decode, response.body)
			if not ok or not data.access_token then
				callback(nil, "Failed to parse token refresh response for " .. email)
				return
			end
			tokens.access_token = data.access_token
			tokens.expiry = os.time() + (data.expires_in or 3600)
			M.write_account_tokens(email, tokens)
			callback(tokens.access_token)
		end),
	})
end

--- Get access tokens for all accounts. Returns { {email, token}, ... } via callback.
--- Skips accounts that fail with a warning.
function M.get_all_access_tokens(callback)
	local account_list = M.get_account_list()
	if #account_list == 0 then
		callback({})
		return
	end

	local results = {}

	local function process_next(index)
		if index > #account_list then
			callback(results)
			return
		end

		local email = account_list[index]
		M.get_access_token(email, function(token, err)
			if token then
				table.insert(results, { email = email, token = token })
			else
				vim.notify(
					"GCal: skipping " .. email .. ": " .. (err or "unknown error"),
					vim.log.levels.WARN,
					{ title = "GCal Notify" }
				)
			end
			process_next(index + 1)
		end)
	end

	process_next(1)
end

--- Fetch the email address for an access token via Google userinfo API.
function M._fetch_userinfo(access_token, callback)
	curl.get(USERINFO_URL, {
		headers = { ["Authorization"] = "Bearer " .. access_token },
		callback = vim.schedule_wrap(function(response)
			if response.status ~= 200 then
				callback(nil, "Userinfo request failed (HTTP " .. response.status .. ")")
				return
			end
			local ok, data = pcall(vim.fn.json_decode, response.body)
			if not ok or not data.email then
				callback(nil, "Failed to parse userinfo response")
				return
			end
			callback(data.email)
		end),
	})
end

function M.start_auth_flow()
	if auth_in_progress then
		vim.notify("Authorization already in progress", vim.log.levels.WARN, { title = "GCal Notify" })
		return
	end

	local creds, err = M.read_credentials()
	if not creds then
		vim.notify(err, vim.log.levels.ERROR, { title = "GCal Notify" })
		return
	end

	auth_in_progress = true

	local server = vim.loop.new_tcp()
	server:bind("127.0.0.1", REDIRECT_PORT)

	server:listen(1, function(listen_err)
		if listen_err then
			auth_in_progress = false
			vim.schedule(function()
				vim.notify(
					"Failed to start auth server: " .. listen_err,
					vim.log.levels.ERROR,
					{ title = "GCal Notify" }
				)
			end)
			return
		end

		local client = vim.loop.new_tcp()
		server:accept(client)

		client:read_start(function(read_err, data)
			if read_err or not data then
				auth_in_progress = false
				client:close()
				server:close()
				return
			end

			-- Extract authorization code from the GET request
			local code = data:match("[?&]code=([^&%s]+)")
			if not code then
				auth_in_progress = false
				local error_msg = data:match("[?&]error=([^&%s]+)") or "unknown"
				local html = "<html><body><h2>Authorization failed: "
					.. error_msg
					.. "</h2><p>You can close this tab.</p></body></html>"
				local response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: "
					.. #html
					.. "\r\nConnection: close\r\n\r\n"
					.. html
				client:write(response, function()
					client:close()
					server:close()
				end)
				vim.schedule(function()
					vim.notify(
						"Authorization denied: " .. error_msg,
						vim.log.levels.ERROR,
						{ title = "GCal Notify" }
					)
				end)
				return
			end

			code = vim.uri_decode(code)

			local html =
				"<html><body><h2>Authorization successful!</h2><p>You can close this tab and return to Neovim.</p></body></html>"
			local response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: "
				.. #html
				.. "\r\nConnection: close\r\n\r\n"
				.. html
			client:write(response, function()
				client:close()
				server:close()
			end)

			-- Exchange code for tokens
			vim.schedule(function()
				M._exchange_code(creds, code)
			end)
		end)
	end)

	-- Build authorization URL
	local params = {
		client_id = creds.client_id,
		redirect_uri = REDIRECT_URI,
		response_type = "code",
		scope = SCOPE,
		access_type = "offline",
		prompt = "consent",
	}

	local query_parts = {}
	for k, v in pairs(params) do
		table.insert(query_parts, k .. "=" .. vim.uri_encode(v, "rfc2396"))
	end
	local auth_url = GOOGLE_AUTH_URL .. "?" .. table.concat(query_parts, "&")

	-- Open browser
	local open_cmd
	if vim.fn.has("mac") == 1 then
		open_cmd = { "open", auth_url }
	elseif vim.fn.has("unix") == 1 then
		open_cmd = { "xdg-open", auth_url }
	else
		open_cmd = { "cmd", "/c", "start", auth_url }
	end

	vim.fn.jobstart(open_cmd, { detach = true })
	vim.notify("Opening browser for Google authorization...", vim.log.levels.INFO, { title = "GCal Notify" })
end

function M._exchange_code(creds, code)
	curl.post(GOOGLE_TOKEN_URL, {
		body = vim.fn.json_encode({
			client_id = creds.client_id,
			client_secret = creds.client_secret,
			code = code,
			grant_type = "authorization_code",
			redirect_uri = REDIRECT_URI,
		}),
		headers = { ["Content-Type"] = "application/json" },
		callback = vim.schedule_wrap(function(response)
			if response.status ~= 200 then
				auth_in_progress = false
				vim.notify(
					"Token exchange failed (HTTP " .. response.status .. ")",
					vim.log.levels.ERROR,
					{ title = "GCal Notify" }
				)
				return
			end
			local ok, data = pcall(vim.fn.json_decode, response.body)
			if not ok or not data.access_token then
				auth_in_progress = false
				vim.notify("Failed to parse token response", vim.log.levels.ERROR, { title = "GCal Notify" })
				return
			end

			local tokens = {
				access_token = data.access_token,
				refresh_token = data.refresh_token,
				expiry = os.time() + (data.expires_in or 3600),
			}

			-- Fetch the account email via userinfo API
			M._fetch_userinfo(data.access_token, function(email, info_err)
				auth_in_progress = false
				if email then
					M.write_account_tokens(email, tokens)
					vim.notify(
						"Google Calendar authorized: " .. email,
						vim.log.levels.INFO,
						{ title = "GCal Notify" }
					)
				else
					-- Fallback: store under "unknown" if userinfo fails
					M.write_account_tokens("unknown", tokens)
					vim.notify(
						"Authorized, but couldn't fetch email: " .. (info_err or "unknown error"),
						vim.log.levels.WARN,
						{ title = "GCal Notify" }
					)
				end
			end)
		end),
	})
end

--- Migrate legacy single-account tokens.json to multi-account accounts.json.
function M._migrate_legacy()
	local content = vim.fn.readfile(legacy_tokens_path)
	local ok, tokens = pcall(vim.fn.json_decode, table.concat(content, "\n"))
	if not ok or not tokens or not tokens.refresh_token then
		return {}
	end

	local accounts = { default = tokens }
	M.write_all_accounts(accounts)

	vim.defer_fn(function()
		vim.notify(
			"GCal Notify: Migrated existing account as \"default\".\nRun :GcalAddAccount to re-authorize with email identification.",
			vim.log.levels.INFO,
			{ title = "GCal Notify" }
		)
	end, 3000)

	return accounts
end

return M
