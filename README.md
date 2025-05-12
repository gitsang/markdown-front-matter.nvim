# Markdown Front Matter

A Neovim plugin for automated Markdown front matter generation and management.

## 1. Features

- **Generate Front Matter**: Generate YAML front matter for Markdown documents.
- **Generate metadata by llm**: Use llm to generate metadata(title, description, categories, tags)
- **Intelligent Formatting**:
  - Auto-generated slugs in kebab-case from filenames
  - ISO 8601 compliant dates with timezone information

## 2. Installation

### 2.1 Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'gitsang/markdown-front-matter.nvim',
  opts = {},
}
```

### 2.2 Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'gitsang/markdown-front-matter.nvim',
  opts = {}
}
```

## 3. Configuration

```lua
opts = {
  llm = {
    provider = "openai",
    providers = {
      ["openai"] = {
        base_url = "https://api.openai.com/v1",
        -- api_key = "YOUR_API_KEY",
        api_key = function()
          -- function to get your API key
          return os.getenv("OPENAI_API_KEY")
        end,
        model = "gpt-3.5-turbo",
      }
    }
  }
}
```

## 4. Usage

The plugin provides a simple command to generate or update front matter:

```vim
:MarkdownFrontMatter
```

## 5. Documentation

For detailed documentation, please refer to `:help markdown-front-matter` within Neovim or view the [documentation file](doc/markdown-front-matter.txt).

## 6. TODO

- [ ] Configurable timezone
- [ ] Customizable fields
- [ ] Auto update on save

## 7. License

[MIT License](LICENSE)

## 8. Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
