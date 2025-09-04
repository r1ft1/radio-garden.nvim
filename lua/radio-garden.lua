local M = {}

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

function M.search_api(input)
	local url = (string.format("'https://radio.garden/api/search/secure?q=%s'", input))

	-- print(url)
	local curl_cmd = "curl "
		.. url
		.. " -A \"Mozilla/5.0 (compatible;  MSIE 7.01; Windows NT 5.0)\" | jq '[.hits.hits[] | ._source | if .stream != null then {title:.title, country:.subtitle, stream_url: .stream} else empty end]'"
	local result_handle = io.popen(curl_cmd)
	local buffer = vim.api.nvim_create_buf(true, false)
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
	for i, r in pairs(lua_json) do
		print(i, r.title, r.stream_url)
		vim.api.nvim_buf_set_lines(buffer, -1, -1, false, { r.title .. " - " .. r.stream_url })
	end
	--
	local Picker = require("snacks.picker")

	Picker.pick({
		items = lua_json,
		format = function(item, picker)
			return { { item.title } }
		end,
		confirm = function(picker, item)
			if item then
				local MPV = vim.system({ "mpv", item.stream_url, "--loop-playlist=force" }, { stdin = true })
				vim.notify("Tuning in to " .. item.title .. " - " .. item.stream_url)
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
		M.search_api(input)
	end)
end

function M.setup(opts)
	STREAM_URLS = {}
	-- Merge user options with defaults
	opts = opts or {}

	-- Create the user command
	vim.api.nvim_create_user_command("MPV", function()
		local stream_url = STREAM_URLS[1]
	end, {})

	-- Search Radio Garden API by station name
	-- Use opts.keymap if provided, otherwise default to '<leader>hw'
	local keymap = opts.keymap or "<leader>r"

	-- Create the keymap
	vim.keymap.set("n", keymap, M.search_radio, {
		desc = "Say hello from our plugin",
		silent = true, -- Prevents the command from being echoed in the command line
	})
end
return M
