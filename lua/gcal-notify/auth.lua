local curl = require("plenary.curl")

local M = {}

local config = {}
local data_dir = vim.fn.stdpath("data") .. "/gcal-notify"
local tokens_path = data_dir .. "/tokens.json"

local GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
local GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
local REDIRECT_PORT = 8089
local REDIRECT_URI = "http://localhost:" .. REDIRECT_PORT
local SCOPE = "https://www.googleapis.com/auth/calendar.readonly"

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

function M.read_tokens()
	if vim.fn.filereadable(tokens_path) == 0 then
		return nil
	end
	local content = vim.fn.readfile(tokens_path)
	local ok, tokens = pcall(vim.fn.json_decode, table.concat(content, "\n"))
	if not ok then
		return nil
	end
	return tokens
end

function M.write_tokens(tokens)
	vim.fn.mkdir(data_dir, "p")
	local json = vim.fn.json_encode(tokens)
	local fd = vim.loop.fs_open(tokens_path, "w", 384) -- 0600
	if fd then
		vim.loop.fs_write(fd, json)
		vim.loop.fs_close(fd)
	end
end

function M.is_authenticated()
	local tokens = M.read_tokens()
	return tokens ~= nil and tokens.refresh_token ~= nil
end

function M.get_access_token(callback)
	local tokens = M.read_tokens()
	if not tokens or not tokens.refresh_token then
		callback(nil, "Not authenticated. Run :GcalSetup first.")
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
				callback(nil, "Token refresh failed (HTTP " .. response.status .. ")")
				return
			end
			local ok, data = pcall(vim.fn.json_decode, response.body)
			if not ok or not data.access_token then
				callback(nil, "Failed to parse token refresh response")
				return
			end
			tokens.access_token = data.access_token
			tokens.expiry = os.time() + (data.expires_in or 3600)
			M.write_tokens(tokens)
			callback(tokens.access_token)
		end),
	})
end

function M.start_auth_flow()
	local creds, err = M.read_credentials()
	if not creds then
		vim.notify(err, vim.log.levels.ERROR, { title = "GCal Notify" })
		return
	end

	local server = vim.loop.new_tcp()
	server:bind("127.0.0.1", REDIRECT_PORT)

	server:listen(1, function(listen_err)
		if listen_err then
			vim.schedule(function()
				vim.notify("Failed to start auth server: " .. listen_err, vim.log.levels.ERROR, { title = "GCal Notify" })
			end)
			return
		end

		local client = vim.loop.new_tcp()
		server:accept(client)

		client:read_start(function(read_err, data)
			if read_err or not data then
				client:close()
				server:close()
				return
			end

			-- Extract authorization code from the GET request
			local code = data:match("[?&]code=([^&%s]+)")
			if not code then
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
					vim.notify("Authorization denied: " .. error_msg, vim.log.levels.ERROR, { title = "GCal Notify" })
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
				vim.notify(
					"Token exchange failed (HTTP " .. response.status .. ")",
					vim.log.levels.ERROR,
					{ title = "GCal Notify" }
				)
				return
			end
			local ok, data = pcall(vim.fn.json_decode, response.body)
			if not ok or not data.access_token then
				vim.notify("Failed to parse token response", vim.log.levels.ERROR, { title = "GCal Notify" })
				return
			end
			local tokens = {
				access_token = data.access_token,
				refresh_token = data.refresh_token,
				expiry = os.time() + (data.expires_in or 3600),
			}
			M.write_tokens(tokens)
			vim.notify(
				"Google Calendar authorized successfully!",
				vim.log.levels.INFO,
				{ title = "GCal Notify" }
			)
		end),
	})
end

return M
