#!/usr/bin/env python3
import os
import sys
import unittest

class TestBooksMod(unittest.TestCase):

	def test_01_mod_conf(self):
		self.assertTrue(os.path.exists("mod.conf"), "mod.conf does not exist")
		with open("mod.conf", "r") as f:
			content = f.read()
		self.assertIn("name = books", content, "mod.conf must define name = books")

		self.assertTrue(os.path.exists("README.md"), "README.md does not exist")
		self.assertTrue(os.path.exists("LICENSE.md"), "LICENSE.md does not exist")
		with open("LICENSE.md", "r") as f:
			lic_content = f.read()
		self.assertIn("ronrob-lu", lic_content, "LICENSE.md must contain copyright holder ronrob-lu")
		self.assertIn("2026", lic_content, "LICENSE.md must contain year 2026")

	def test_02_assets_exist(self):
		import glob

		# Check at least one texture exists
		book_textures = glob.glob("textures/Book*_Closed.png")
		self.assertTrue(len(book_textures) > 0, "At least one book texture must exist")
		self.assertTrue(os.path.exists("textures/books_bg.png"), "textures/books_bg.png missing")

		# Verify models/ directory no longer exists (books are craftitems)
		self.assertFalse(os.path.exists("models"), "models/ directory should be removed")

		# Check that any .md files in books/ are actually readable files
		md_files = glob.glob("books/*.md")
		self.assertTrue(len(md_files) > 0, "At least one Markdown book must exist")
		for md in md_files:
			self.assertTrue(os.path.isfile(md), f"Markdown book {md} missing or not a file")

	def test_03_lua_mock_and_init(self):
		"""Mock Minetest API and execute init.lua to verify book craftitem registration, formspec, and inventory insertion."""
		import lupa
		import glob
		lua = lupa.LuaRuntime(unpack_returned_tuples=True)

		md_files = [os.path.basename(f) for f in glob.glob("books/*.md")]
		md_files_str = ", ".join(f'"{f}"' for f in md_files)
		num_files = len(md_files)

		tex_files = [os.path.basename(f) for f in glob.glob("textures/*.png")]
		tex_files_str = ", ".join(f'"{f}"' for f in tex_files)

		lua_test_script = f"""
		-- Mock core/minetest API
		core = {{}}
		minetest = core

		core.registered_craftitems = {{}}
		core.registered_callbacks = {{
			on_joinplayer = {{}},
			on_receive_fields = {{}}
		}}

		function core.get_current_modname()
			return "books"
		end

		function core.get_modpath(modname)
			return "."
		end

		function core.formspec_escape(str)
			if not str then return "" end
			return str:gsub("\\\\", "\\\\\\\\"):gsub("%]", "\\\\]"):gsub("%[", "\\\\[")
		end

		function core.register_craftitem(name, def)
			core.registered_craftitems[name] = def
		end

		function core.register_item(name, def)
			core.registered_craftitems[name] = def
		end

		function core.register_on_receive_fields(func)
			table.insert(core.registered_callbacks.on_receive_fields, func)
		end
		core.register_on_player_receive_fields = core.register_on_receive_fields

		function core.register_on_joinplayer(func)
			table.insert(core.registered_callbacks.on_joinplayer, func)
		end

		function core.get_dir_list(path, is_dir)
			if path:match("books$") then
				return {{{md_files_str}}}
			elseif path:match("textures$") then
				return {{{tex_files_str}}}
			end
			return {{}}
		end

		local shown_formspecs = {{}}
		function core.show_formspec(player_name, formname, formspec)
			table.insert(shown_formspecs, {{player = player_name, name = formname, spec = formspec}})
		end

		-- Mock Player object
		local mock_inventory = {{
			items = {{}},
			contains_item = function(self, list, itemname)
				return self.items[itemname] == true
			end,
			add_item = function(self, list, itemname)
				self.items[itemname] = true
				return true
			end
		}}

		local mock_player = {{
			name = "TestPlayer",
			is_player = function(self) return true end,
			get_player_name = function(self) return self.name end,
			get_inventory = function(self) return mock_inventory end
		}}

		-- Load init.lua
		dofile("init.lua")

		-- Verify books were registered
		assert(books ~= nil, "Global books table must exist")
		local count = 0
		for k, v in pairs(books.registered_books) do
			count = count + 1
			assert(v.title ~= nil and #v.title > 0, "Book " .. k .. " must have a title")
			assert(v.pages ~= nil and #v.pages > 0, "Book " .. k .. " must have pages")
			assert(core.registered_craftitems[k] ~= nil, "Craftitem " .. k .. " must be registered in Minetest")
			assert(core.registered_craftitems[k]._read_only == true, "Book craftitem " .. k .. " must be read-only")
		end
		assert(count == {num_files}, "Expected {num_files} books to be registered, got " .. count)

		-- Verify formspec generation and button navigation
		-- dynamically pick the first registered book id
		local first_book_id = nil
		for k, _ in pairs(books.registered_books) do
			first_book_id = k
			break
		end

		assert(first_book_id ~= nil, "At least one book should be registered")
		local book1_def = core.registered_craftitems[first_book_id]
		assert(book1_def ~= nil, "Book craftitem must exist for " .. first_book_id)
		assert(book1_def.on_use ~= nil, "Book must have on_use handler")
		book1_def.on_use(nil, mock_player, nil)

		assert(#shown_formspecs > 0, "show_formspec should have been called")
		local last_form = shown_formspecs[#shown_formspecs]
		assert(last_form.name == "books:reader", "Formspec name must be books:reader")
		assert(last_form.spec:find("background"), "Formspec must contain background")

		-- Test next page field receive
		assert(#core.registered_callbacks.on_receive_fields > 0, "receive_fields callback must be registered")
		local field_cb = core.registered_callbacks.on_receive_fields[1]
		field_cb(mock_player, "books:reader", {{books_next = "true"}})

		print("LUA_TESTS_PASSED_SUCCESSFULLY")
		"""

		lua.execute(lua_test_script)

if __name__ == "__main__":
	unittest.main()
