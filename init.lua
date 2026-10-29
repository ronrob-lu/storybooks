-- Mod: books
-- Read-only books initialized from books/ folder and given on player join

books = {}
books.registered_books = {}
books.player_state = {}

local modname = core.get_current_modname and core.get_current_modname() or "books"
local modpath = core.get_modpath and core.get_modpath(modname) or "."

-- Convert markdown formatting to Minetest hypertext tags
local function format_markdown_to_hypertext(text)
	if not text then return "" end

	local lines = {}
	for raw_line in text:gmatch("([^\r\n]*)\r?\n?") do
		local line = raw_line
		if line:sub(1, 2) == "# " then
			local header = line:sub(3)
			line = "<style font_size=20 color=#660000><b>" .. header .. "</b></style>"
		elseif line:sub(1, 3) == "## " then
			local header = line:sub(4)
			line = "<style font_size=17 color=#441100><b>" .. header .. "</b></style>"
		elseif line:sub(1, 4) == "### " then
			local header = line:sub(5)
			line = "<style font_size=15 color=#332211><b>" .. header .. "</b></style>"
		end

		-- Convert bold **text** to <b>text</b>
		line = line:gsub("%*%*(.-)%*%*", "<b>%1</b>")
		-- Convert italic *text* to <i>text</i>
		line = line:gsub("%*(.-)%*", "<i>%1</i>")

		table.insert(lines, line)
	end

	return table.concat(lines, "\n")
end

-- Read file contents
local function read_file(filepath)
	local file, err = io.open(filepath, "r")
	if not file then
		return nil, err
	end
	local content = file:read("*a")
	file:close()
	return content
end

-- Parse title and pages from markdown content
local function parse_book_file(content, fallback_title)
	local title = fallback_title
	local raw_content = content or ""

	-- Extract title from first H1 heading if present
	local first_line = raw_content:match("^%s*#%s+([^\r\n]+)")
	if first_line then
		title = first_line
	end

	-- Split content into pages separated by '---'
	local page_chunks = {}
	local pos = 1
	while pos <= #raw_content do
		local s, e = raw_content:find("\r?\n%-%-%-\r?\n", pos)
		if s then
			local chunk = raw_content:sub(pos, s - 1)
			if #chunk:gsub("%s", "") > 0 then
				table.insert(page_chunks, chunk)
			end
			pos = e + 1
		else
			local chunk = raw_content:sub(pos)
			if #chunk:gsub("%s", "") > 0 then
				table.insert(page_chunks, chunk)
			end
			break
		end
	end

	if #page_chunks == 0 then
		table.insert(page_chunks, raw_content)
	end

	local pages = {}
	for _, page_text in ipairs(page_chunks) do
		local formatted = format_markdown_to_hypertext(page_text)
		table.insert(pages, formatted)
	end

	return title, pages
end

-- Build formspec for book GUI
function books.get_formspec(book_data, page)
	local total_pages = #book_data.pages
	local current_page = math.max(1, math.min(page or 1, total_pages))
	local content = book_data.pages[current_page] or ""

	local escaped_title = core.formspec_escape and core.formspec_escape(book_data.title) or book_data.title
	local escaped_content = core.formspec_escape and core.formspec_escape(content) or content

	local formspec = "size[12,9]" ..
		"background[0,0;12,9;books_bg.png;true]" ..
		"label[0.8,0.5;" .. escaped_title .. "]" ..
		"hypertext[0.8,1.2;10.4,6.5;book_content;<global font_size=16 color=#2b1d0c>" .. escaped_content .. "]"

	if total_pages > 1 then
		formspec = formspec ..
			"label[5.2,8.0;Page " .. current_page .. " / " .. total_pages .. "]"
		if current_page > 1 then
			formspec = formspec .. "button[0.8,7.8;2,0.8;books_prev;< Previous]"
		end
		if current_page < total_pages then
			formspec = formspec .. "button[9.2,7.8;2,0.8;books_next;Next >]"
		end
	end

	return formspec
end

-- Display book formspec to player
function books.show_book(player, item_name, page)
	if not player or not player:is_player() then return end
	local player_name = player:get_player_name()
	local book_data = books.registered_books[item_name]
	if not book_data then return end

	books.player_state[player_name] = {
		item_name = item_name,
		page = page or 1
	}

	local formspec = books.get_formspec(book_data, page or 1)
	core.show_formspec(player_name, "books:reader", formspec)
end

-- Register formspec button handler
if core.register_on_player_receive_fields then
	core.register_on_player_receive_fields(function(player, formname, fields)
		if formname ~= "books:reader" or not player then return end
		local player_name = player:get_player_name()
		local state = books.player_state[player_name]
		if not state then return end

		local book_data = books.registered_books[state.item_name]
		if not book_data then return end

		if fields.books_prev then
			state.page = math.max(1, state.page - 1)
			books.show_book(player, state.item_name, state.page)
		elseif fields.books_next then
			state.page = math.min(#book_data.pages, state.page + 1)
			books.show_book(player, state.item_name, state.page)
		end
	end)
end

-- Initialize books from books/ directory
local function load_books_from_folder()
	local books_dir = modpath .. "/books"
	local file_list = {}

	if core.get_dir_list then
		local dir_files = core.get_dir_list(books_dir, false) or {}
		for _, fname in ipairs(dir_files) do
			if fname:match("%.md$") or fname:match("%.txt$") then
				table.insert(file_list, fname)
			end
		end
	end

	-- Fallback list if get_dir_list is empty or unavailable
	if #file_list == 0 then
		file_list = {
			"book_1.md", "book_2.md", "book_3.md", "book_4.md",
			"book_5.md", "book_6.md", "book_7.md", "book_8.md"
		}
	end

	table.sort(file_list)

	local register_item_fn = core.register_craftitem or (minetest and minetest.register_craftitem) or core.register_item

	for idx, fname in ipairs(file_list) do
		local filepath = books_dir .. "/" .. fname
		local content = read_file(filepath)

		if content then
			local num_in_name = fname:match("book_(%d+)")
			local tex_idx = num_in_name and tonumber(num_in_name) or idx

			local book_id = fname:gsub("%..+$", "")
			local item_name = "books:" .. book_id
			local fallback_title = "Book " .. tex_idx
			local title, pages = parse_book_file(content, fallback_title)

			local texture_name = "Book" .. tex_idx .. "_Closed.png"

			books.registered_books[item_name] = {
				id = book_id,
				title = title,
				content = content,
				pages = pages,
				texture = texture_name
			}

			if register_item_fn then
				register_item_fn(item_name, {
					description = title,
					inventory_image = texture_name,
					wield_image = texture_name,
					groups = {book = 1, read_only_book = 1},
					_read_only = true,

					on_use = function(itemstack, user, pointed_thing)
						if user and user:is_player() then
							books.show_book(user, item_name, 1)
						end
						return itemstack
					end,

					on_secondary_use = function(itemstack, user, pointed_thing)
						if user and user:is_player() then
							books.show_book(user, item_name, 1)
						end
						return itemstack
					end,
				})
			end
		end
	end
end

load_books_from_folder()
