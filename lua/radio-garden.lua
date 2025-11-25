local M = {}

M.radio_buf = nil
M.station_name = nil
M.station_url = nil
M.station_country = nil
M.playing = nil

function M.get_pid()
	local lines = vim.api.nvim_buf_get_lines(M.radio_buf, 0, 1, false)

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
	local url = (string.format("'https://vozymkqyhrenvktrunii.supabase.co/rest/v1/stations?name=ilike.*%s*'", input))
	local curl_cmd = "curl -s "
		.. url
		.. ' -H "apikey: sb_publishable_BpdVJa3Y2tvv4GNxDzcIKQ_Hd0UQV72"'
		.. ' -H "Content-Type: application/json"'
		.. ' -H "Accept: application/json"'
		.. " | jq ."

	-- print(curl_cmd)

	local result_handle = io.popen(curl_cmd)
	-- local buffer = vim.api.nvim_create_buf(true, false)
	local scratch = vim.api.nvim_create_buf(false, true)
	-- if radio_buf doesn't exist, create one
	--
	if result_handle == nil then
		-- vim.api.nvim_buf_set_lines(scratch, -1, -1, false, { "FAILED" })
		vim.notify("Error executing search command.", vim.log.levels.ERROR)
		return
	end

	local res = {}
	local json_string = ""
	for line in result_handle:lines() do
		-- vim.api.nvim_buf_set_lines(scratch, -1, -1, false, { line })
		json_string = json_string .. line
		table.insert(res, line)
	end

	-- vim.api.nvim_open_win(scratch, true, { relative = "win", row = 30, col = 30, width = 120, height = 30 })
	--
	result_handle:close()
	--
	local lua_json = vim.fn.json_decode(json_string)
	--
	-- --
	local Picker = require("snacks.picker")

	Picker.pick({
		items = lua_json,
		format = function(item, picker)
			return { { item.name } }
		end,
		confirm = function(picker, item)
			if item then
				if M.get_pid() ~= nil then
					vim.system({ "kill", M.get_pid() }, { stdin = true })
				end
				local radio_process = vim.system({ "mpv", item.stream_url, "--loop-playlist=force" }, { stdin = true })
				vim.api.nvim_buf_set_lines(M.radio_buf, 0, 1, false, { tostring(radio_process.pid) })
				vim.api.nvim_buf_set_lines(M.radio_buf, 1, 2, false, { item.stream_url })
				vim.api.nvim_buf_set_lines(M.radio_buf, 2, 3, false, { item.name })
				vim.api.nvim_buf_set_lines(M.radio_buf, 3, 4, false, { item.country })
				vim.api.nvim_buf_set_lines(M.radio_buf, 4, 5, false, { "true" })
				--TODO: write a single line of json and decode that

				vim.notify("Tuning in to " .. item.name .. " - " .. item.stream_url)
				print(radio_process.pid)
			else
				vim.notify("No item selected", vim.log.levels.WARN)
			end
			picker:close()
		end,
	})
end

function M.get_info() end

function M.search_radio()
	local Snacks = require("snacks.input")

	Snacks.input({
		prompt = "Search Radio Garden Station Names: ",
	}, function(input)
		M.search_api_and_play(input)
	end)
end

function M.setup(opts)
	-- Merge user options with defaults
	opts = opts or {}

	M.check_radio_buf()
	-- Create the user command
	vim.keymap.set("n", "<leader>r", function()
		print("r pressed")
		local Snacks = require("snacks")
		local win = Snacks.win({
			text = vim.api.nvim_buf_get_lines(M.radio_buf, 1, 4, false),
			border = "double",
			width = 0.6,
			height = 0.6,
			wo = {
				spell = false,
				wrap = false,
				signcolumn = "yes",
				statuscolumn = " ",
				conceallevel = 3,
			},
			keys = {
				b = function(self)
					local playing = vim.api.nvim_buf_get_lines(M.radio_buf, 4, 5, false)
					if playing[1] == "true" then
						vim.notify("Stopping Radio", vim.log.levels.WARN)
						vim.system({ "kill", "-SIGSTOP", M.get_pid() }, { stdin = true })
						vim.api.nvim_buf_set_lines(M.radio_buf, 4, 5, false, { "false" })
					else
						vim.notify("Radio is not playing", vim.log.levels.WARN)
						vim.system({ "kill", "-SIGCONT", M.get_pid() }, { stdin = true })

						vim.api.nvim_buf_set_lines(M.radio_buf, 4, 5, false, { "true" })
					end
					self:close()
				end,
			},
		})
		win:set_title("Radio Garden", "center")
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
