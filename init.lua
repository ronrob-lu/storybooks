-- Mod: books
-- Read-only books initialized from books/ folder and given on player join

books = {}
books.registered_books = {}
books.player_state = {}

local modname = core.get_current_modname and core.get_current_modname() or "books"
local modpath = core.get_modpath and core.get_modpath(modname) or "."

-- Convert markdown formatting to Minetest hypertext tags
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
		table.insert(pages, page_text)
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
		"style_type[label;textcolor=#111111]" ..
		"style_type[textarea;textcolor=#111111]" ..
		"background[0,0;12,9;books_bg.png;true]" ..
		"label[0.8,0.5;" .. escaped_title .. "]" ..
		"textarea[0.8,1.2;10.4,6.5;;;" .. escaped_content .. "]"

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
	local textures_dir = modpath .. "/textures"
	local file_list = {}
	local texture_count = 0

	if core.get_dir_list then
		local dir_files = core.get_dir_list(books_dir, false) or {}
		for _, fname in ipairs(dir_files) do
			if fname:match("%.md$") or fname:match("%.txt$") then
				table.insert(file_list, fname)
			end
		end

		-- Count available book textures
		local tex_files = core.get_dir_list(textures_dir, false) or {}
		for _, fname in ipairs(tex_files) do
			if fname:match("^Book%d+_Closed%.png$") then
				texture_count = texture_count + 1
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

	if texture_count == 0 then
		texture_count = 8
	end

	table.sort(file_list)

	local register_item_fn = core.register_craftitem or (minetest and minetest.register_craftitem) or core.register_item

	for idx, fname in ipairs(file_list) do
		local filepath = books_dir .. "/" .. fname
		local content = read_file(filepath)

		if content then
			local num_in_name = fname:match("book_(%d+)")
			local parsed_idx = num_in_name and tonumber(num_in_name) or idx
			local tex_idx = ((parsed_idx - 1) % texture_count) + 1

			local book_id = fname:gsub("%..+$", "")
			local item_name = "books:" .. book_id
			local fallback_title = "Book " .. parsed_idx
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
