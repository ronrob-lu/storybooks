# 📚 Books Mod for Minetest / Luanti

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

Transform your Minetest / Luanti worlds into immersive libraries and rich story-driven realms! The **Books** mod brings custom book item icons, dynamic Markdown text parsing, and elegant multi-page reading GUIs right into your game.

---

## ✨ Features

- 📖 **Read-Only Inventory Items**: 8 unique book items with distinct closed book cover icons. Books are inventory items (craftitems) designed for reading and collection.
- 📝 **Markdown-Powered Library**: Automatically reads `.md` files directly from the `books/` directory and converts them into read-only in-game books!
- 📑 **Multi-Page Reader GUI**: Clean, interactive book reading interface with background textures and seamless previous/next page navigation.
- ✂️ **Selectable Text**: Text inside the books can be easily selected and copied.
- 🎒 **Automatic Starter Distribution**: Automatically provides registered books into the inventory of joining players so nobody misses the adventure.
- 🛠️ **Fully Customizable**: Adding a new book is as simple as placing a new `.md` file in the `books/` folder!

---

## 🚀 Installation

1. Download or clone this repository:
   ```bash
   git clone https://github.com/ronrob-lu/books.git books
   ```
2. Place the `books` folder into your Minetest/Luanti `mods/` directory.
3. Enable the `books` mod in your world configuration or `world.mt`.

---

## 📖 How to Use

### In-Game Usage
- **Reading Books**: Hold a book in your hand and **left-click (use)** to open the reading GUI.
- **Page Navigation**: Click **`< Previous`** and **`Next >`** buttons at the bottom of the book interface to turn pages.

### Creating Your Own Books
Adding new lore to your world is effortless:

1. Navigate to the `books/` directory inside the mod folder.
2. Create a new `.md` (Markdown) file, e.g., `books/book_9.md` or `books/mystic_journal.md`.
3. Use standard Markdown formatting:
   - `# Book Title`: Sets the main book title (first `#` line).
   - `## Section Header`: Highlighted chapter or section headers.
   - `---`: Inserts a page break to split content across multiple pages!
   - `**bold text**` and `*italic text*`: Adds emphasis to your writing.

#### Example Markdown File (`books/book_9.md`):
```markdown
# The Alchemist's Notes

## Chapter 1: Rare Herbs

In the high mountains grows the legendary Moonflower. Its petals shimmer under moonlight.

---
## Chapter 2: Potions

Combine Moonflower petals with clear spring water to craft an elixir of night vision.
```

---

## 🏗️ Technical Details & API

- **Mod Name**: `books`
- **Dependencies**: None (Optional: `default`)
- **Structure**:
  - `init.lua`: Core Lua code for loading books, converting Markdown, generating formspecs, and handling events.
  - `books/`: Contains Markdown content files (`book_1.md` through `book_8.md`).
  - `textures/`: Contains PNG textures for books (`Book1_Closed.png` through `Book8_Closed.png`) and reading background UI.

---

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE.md](LICENSE.md) file for details.

Copyright (c) 2026 **ronrob-lu**
