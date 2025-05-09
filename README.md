# Markdown Front Matter

A Neovim plugin for automated Markdown front matter generation and management.

## 1. Features

- **Automatic Front Matter Creation**: Generate YAML front matter for Markdown files
- **Smart Update**: Update existing front matter while preserving structure
- **Intelligent Formatting**:
  - Auto-generated slugs in kebab-case from filenames
  - ISO 8601 compliant dates with timezone information
  - YAML-compliant formatting using plenary.nvim

## 2. Installation

### 2.1 Requirements

- Neovim >= 0.8.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### 2.2 Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'gitsang/markdown-front-matter.nvim',
  requires = {'nvim-lua/plenary.nvim'},
  config = function()
    require('markdown-front-matter').setup()
  end
}
```

### 2.3 Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'gitsang/markdown-front-matter.nvim',
  dependencies = {'nvim-lua/plenary.nvim'},
  config = function()
    require('markdown-front-matter').setup()
  end
}
```

## 3. Usage

The plugin provides a simple command to generate or update front matter:

```
:MarkdownFrontMatter
```

This will create front matter at the top of your Markdown file with the following fields:

- `title`: Empty by default
- `slug`: Generated from filename
- `description`: Empty by default
- `date`: Current timestamp
- `lastmod`: Current timestamp
- `weight`: 1 by default
- `categories`: Empty array by default
- `tags`: Empty array by default

### 3.1 Auto-update Mode

Add the following comment within your front matter to enable automatic updates:

```
<!-- markdown-front-matter auto -->
```

## 4. Customization

The plugin currently uses sensible defaults. More customization options will be available in future updates.

## 5. Documentation

For detailed documentation, please refer to `:help markdown-front-matter` within Neovim or view the [documentation file](doc/markdown-front-matter.txt).

## 6. License

[MIT License](LICENSE)

## 7. Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
