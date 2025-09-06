local M = {}

-- M.playing = false
M.radio_buf = nil

function M.get_pid()
	local lines = vim.api.nvim_buf_get_lines(M.radio_buf, -2, -1, false)
	if lines[1] == nil then
		return nil
	end
	print(lines[1])
	return lines[1]
end

function Dump(o)
	if type(o) == "table" then
		local s = "{ "
		for k, v in pairs(o) do
			if type(k) ~= "number" then
				k = '"' .. k .. '"'
			end
			s = s .. "[" .. k .. "] = " .. Dump(v) .. ","
		end
		return s .. "} "
	else
		return tostring(o)
	end
end
function Mysplit(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

function M.check_radio_buf()
	local buf_list = vim.api.nvim_list_bufs()
	for i in ipairs(buf_list) do
		local split = Mysplit(vim.api.nvim_buf_get_name(buf_list[i]), "/")
		if split[#split] == "radio_buf" then
			M.radio_buf = buf_list[i]
			return
		end
	end
	M.radio_buf = vim.api.nvim_create_buf(false, true) -- Create a scratch buffer
	vim.api.nvim_buf_set_name(M.radio_buf, "radio_buf") -- Name the buffer
end

function M.search_api_and_play(input)
	local url = (string.format("'https://radio.garden/api/search/secure?q=%s'", input))

	-- print(url)
	local curl_cmd = "curl "
		.. url
		.. " -A \"Mozilla/5.0 (compatible;  MSIE 7.01; Windows NT 5.0)\" | jq '[.hits.hits[] | ._source | if .stream != null then {title:.title, country:.subtitle, stream_url: .stream} else empty end]'"
	local result_handle = io.popen(curl_cmd)
	-- local buffer = vim.api.nvim_create_buf(true, false)

	-- if radio_buf doesn't exist, create one

	-- print(result_handle)
	if result_handle == nil then
		vim.notify("Error executing search command.", vim.log.levels.ERROR)
		return
	end
	local res = {}
	local json_string = ""
	for line in result_handle:lines() do
		json_string = json_string .. line
		table.insert(res, line)
	end

	--
	result_handle:close()

	-- vim.api.nvim_buf_set_lines(buffer, -2, -1, false, { json_string })
	-- vim.api.nvim_open_win(buffer, true, {
	-- 	relative = "win",
	-- 	row = 3,
	-- 	col = 3,
	-- 	width = 50,
	-- 	height = 50,
	-- })

	--
	-- print(Dump(res))
	--
	-- print("You entered: " .. input)

	local lua_json = vim.fn.json_decode(json_string)
	-- for i, r in pairs(lua_json) do
	-- 	print(i, r.title, r.stream_url)
	-- 	-- vim.api.nvim_buf_set_lines(buffer, -1, -1, false, { r.title .. " - " .. r.stream_url })
	-- end
	-- --
	local Picker = require("snacks.picker")

	Picker.pick({
		items = lua_json,
		format = function(item, picker)
			return { { item.title } }
		end,
		confirm = function(picker, item)
			if item then
				if M.get_pid() ~= nil then
					vim.system({ "kill", M.get_pid() }, { stdin = true })
				end
				local radio_process = vim.system({ "mpv", item.stream_url, "--loop-playlist=force" }, { stdin = true })
				vim.api.nvim_buf_set_lines(M.radio_buf, -2, -1, false, { tostring(radio_process.pid) })

				vim.notify("Tuning in to " .. item.title .. " - " .. item.stream_url)
				print(radio_process.pid)
			else
				vim.notify("No item selected", vim.log.levels.WARN)
			end
			picker:close()
		end,
	})
end

function M.search_radio()
	local Snacks = require("snacks.input")

	Snacks.input({
		prompt = "Search Radio Garden Station Names: ",
	}, function(input)
		M.search_api_and_play(input)
	end)
end

function M.setup(opts)
	STREAM_URLS = {}
	-- Merge user options with defaults
	opts = opts or {}

	M.check_radio_buf()
	-- Create the user command
	vim.api.nvim_create_user_command("MPV", function()
		local stream_url = STREAM_URLS[1]
	end, {})

	-- Search Radio Garden API by station name
	-- Use opts.keymap if provided, otherwise default to '<leader>hw'
	-- local keymap = opts.keymap or "<leader>r"

	vim.keymap.set("n", "<leader>r", function()
		local Snacks = require("snacks.win")
		Snacks.win({
			enter = true,
			width = 0.6,
			height = 0.6,
			wo = {
				spell = false,
				wrap = false,
				signcolumn = "yes",
				statuscolumn = " ",
				conceallevel = 3,
			},
		})
	end)
	-- Create the keymap
	vim.keymap.set("n", "<leader>rs", M.search_radio, {
		desc = "Search Radio Garden",
		silent = true, -- Prevents the command from being echoed in the command line
	})

	vim.keymap.set("n", "<leader>rp", function()
		if M.get_pid() == nil then
			vim.notify("No radio is playing", vim.log.levels.WARN)
			return
		else
			vim.notify("Radio Paused", vim.log.levels.WARN)
			vim.system({ "kill", "-SIGSTOP", M.get_pid() }, { stdin = true })
		end
	end, { desc = "Pause Radio" })

	vim.keymap.set("n", "<leader>rr", function()
		if M.get_pid() == nil then
			vim.notify("No radio is playing", vim.log.levels.WARN)
			return
		else
			vim.notify("Radio Resumed", vim.log.levels.WARN)
			vim.system({ "kill", "-SIGCONT", M.get_pid() }, { stdin = true })
		end
	end, { desc = "Pause Radio" })
end
return M
