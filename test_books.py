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
		# Check textures for 8 closed books
		for i in range(1, 9):
			tex = f"textures/Book{i}_Closed.png"
			self.assertTrue(os.path.exists(tex), f"Texture {tex} missing")
		self.assertTrue(os.path.exists("textures/books_bg.png"), "textures/books_bg.png missing")

		# Verify models/ directory no longer exists (books are craftitems)
		self.assertFalse(os.path.exists("models"), "models/ directory should be removed")

		# Check books/ for book_1.md through book_8.md
		for i in range(1, 9):
			md = f"books/book_{i}.md"
			self.assertTrue(os.path.exists(md), f"Markdown book {md} missing")

	def test_03_lua_mock_and_init(self):
		"""Mock Minetest API and execute init.lua to verify book craftitem registration, formspec, and inventory insertion."""
		import lupa
		lua = lupa.LuaRuntime(unpack_returned_tuples=True)

		lua_test_script = r"""
		-- Mock core/minetest API
		core = {}
		minetest = core

		core.registered_craftitems = {}
		core.registered_callbacks = {
			on_joinplayer = {},
			on_receive_fields = {}
		}

		function core.get_current_modname()
			return "books"
		end

		function core.get_modpath(modname)
			return "."
		end

		function core.formspec_escape(str)
			if not str then return "" end
			return str:gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
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
			return {
				"book_1.md", "book_2.md", "book_3.md", "book_4.md",
				"book_5.md", "book_6.md", "book_7.md", "book_8.md"
			}
		end

		local shown_formspecs = {}
		function core.show_formspec(player_name, formname, formspec)
			table.insert(shown_formspecs, {player = player_name, name = formname, spec = formspec})
		end

		-- Mock Player object
		local mock_inventory = {
			items = {},
			contains_item = function(self, list, itemname)
				return self.items[itemname] == true
			end,
			add_item = function(self, list, itemname)
				self.items[itemname] = true
				return true
			end
		}

		local mock_player = {
			name = "TestPlayer",
			is_player = function(self) return true end,
			get_player_name = function(self) return self.name end,
			get_inventory = function(self) return mock_inventory end
		}

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
		assert(count == 8, "Expected 8 books to be registered, got " .. count)

		-- Verify on_joinplayer gives books
		assert(#core.registered_callbacks.on_joinplayer > 0, "on_joinplayer callback must be registered")
		for _, cb in ipairs(core.registered_callbacks.on_joinplayer) do
			cb(mock_player)
		end

		for item_name, _ in pairs(books.registered_books) do
			assert(mock_inventory:contains_item("main", item_name), "Player inventory must contain " .. item_name)
		end

		-- Verify formspec generation and button navigation
		local book1_def = core.registered_craftitems["books:book_1"]
		assert(book1_def.on_use ~= nil, "Book must have on_use handler")
		book1_def.on_use(nil, mock_player, nil)

		assert(#shown_formspecs > 0, "show_formspec should have been called")
		local last_form = shown_formspecs[#shown_formspecs]
		assert(last_form.name == "books:reader", "Formspec name must be books:reader")
		assert(last_form.spec:find("background"), "Formspec must contain background")

		-- Test next page field receive
		assert(#core.registered_callbacks.on_receive_fields > 0, "receive_fields callback must be registered")
		local field_cb = core.registered_callbacks.on_receive_fields[1]
		field_cb(mock_player, "books:reader", {books_next = "true"})

		print("LUA_TESTS_PASSED_SUCCESSFULLY")
		"""

		lua.execute(lua_test_script)

if __name__ == "__main__":
	unittest.main()
