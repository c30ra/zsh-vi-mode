# ZSH VI Mode - Module Structure

This document describes the modular organization of the `zsh-vi-mode` plugin, making it easier to maintain and extend.

## Directory Structure

```
zsh-vi-mode/
├── lib/                           # Module directory
│   ├── constants.zsh             # Global constants and default settings
│   ├── utils.zsh                 # Utility functions (helpers, checks)
│   ├── keybindings.zsh           # Key binding and readkey functions
│   ├── mode-manager.zsh          # VI mode selection and switching
│   ├── editor.zsh                # Text editing operations (yank, delete, change)
│   ├── repeat.zsh                # Repeat command functionality
│   ├── surround.zsh              # Surround text object operations
│   ├── keywords.zsh              # Keyword switching (number, boolean, etc.)
│   ├── ui.zsh                    # Cursor and highlight management
│   ├── clipboard.zsh             # System clipboard operations
│   ├── url.zsh                   # URL/path detection and opening
│   └── init.zsh                  # Initialization and setup
├── zsh-vi-mode.zsh              # Main loader (sources all modules)
├── zsh-vi-mode.plugin.zsh       # Plugin entry point
└── README.md                     # Documentation
```

## Module Descriptions

### `lib/constants.zsh`
Defines all global constants, default values, and configuration options.
- Plugin metadata (name, version, repository)
- Mode constants (normal, insert, visual, etc.)
- Cursor style constants
- Default key timeouts and settings
- Command handlers and hooks

### `lib/utils.zsh`
Contains utility and helper functions.
- `zvm_version()` - Display version info
- `zvm_exist_command()` - Check if command exists
- `zvm_exec_commands()` - Execute command hooks
- String manipulation (hex conversion, escaping)
- Word selection helpers
- URL/path detection
- System reporting

### `lib/keybindings.zsh`
Handles key bindings and key reading.
- `zvm_bindkey()` - Bind keys to widgets
- `zvm_readkeys()` - Read and parse key sequences
- `zvm_find_bindkey_widget()` - Find widgets for keys
- NEX and ZLE readkey engine support

### `lib/mode-manager.zsh`
Manages VI mode selection and transitions.
- `zvm_select_vi_mode()` - Switch between modes
- `zvm_enter_insert_mode()` - Enter insert mode
- `zvm_exit_insert_mode()` - Exit insert mode
- `zvm_enter_visual_mode()` - Enter visual mode
- `zvm_exit_visual_mode()` - Exit visual mode
- Mode initialization on line start

### `lib/editor.zsh`
Contains text editing operations.
- `zvm_vi_replace()` - Replace mode
- `zvm_vi_delete()` - Delete operations
- `zvm_vi_yank()` - Yank (copy) operations
- `zvm_vi_change()` - Change operations
- `zvm_vi_put_before()` / `zvm_vi_put_after()` - Put operations
- Selection manipulation
- Kill/delete line operations

### `lib/repeat.zsh`
Handles the repeat (`.`) command functionality.
- `zvm_repeat_change()` - Repeat last change
- `zvm_repeat_insert()` - Repeat insert sequence
- `zvm_reset_repeat_commands()` - Store commands for repeat
- Support for complex repeat scenarios (replace, range changes)

### `lib/surround.zsh`
Implements surround text object operations.
- `zvm_match_surround()` - Identify surround pairs
- `zvm_search_surround()` - Find surround boundaries
- `zvm_select_surround()` - Select surround text objects
- `zvm_change_surround()` - Add/change/delete surround
- `zvm_move_around_surround()` - Navigate between surrounds

### `lib/keywords.zsh`
Keyword switching operations (Ctrl+A/Ctrl+X).
- `zvm_switch_number()` - Increment/decrement numbers
- `zvm_switch_boolean()` - Toggle booleans (true/false, yes/no)
- `zvm_switch_weekday()` - Cycle through weekdays
- `zvm_switch_month()` - Cycle through months
- `zvm_switch_operator()` - Toggle operators (&&/||, ==/!=)
- `zvm_switch_keyword()` - Main switcher function

### `lib/ui.zsh`
User interface elements (cursor and highlighting).
- `zvm_set_cursor()` - Set cursor shape
- `zvm_cursor_style()` - Get cursor escape sequence
- `zvm_update_cursor()` - Update cursor based on mode
- `zvm_highlight()` - Highlight visual selections
- `zvm_update_highlight()` - Refresh highlight display

### `lib/clipboard.zsh`
System clipboard integration.
- `zvm_clipboard_detect()` - Auto-detect clipboard tools
- `zvm_clipboard_available()` - Check if clipboard works
- `zvm_clipboard_copy_buffer()` - Copy to clipboard
- `zvm_clipboard_get()` - Paste from clipboard
- `zvm_paste_clipboard_before()` / `zvm_paste_clipboard_after()` - Paste operations

### `lib/url.zsh`
URL and file path handling.
- `zvm_select_url_or_path()` - Find URL/path at cursor
- `zvm_open_under_cursor()` - Open URL/file (gx command)
- URL regex patterns

### `lib/init.zsh`
Initialization and setup.
- `zvm_init()` - Main initialization function
- ZLE widget creation and registration
- Keybinding setup for all modes
- Configuration function calling
- Lazy keybinding support

## Module Dependencies

```
constants.zsh (no dependencies)
       ↓
utils.zsh (depends on constants)
       ↓
keybindings.zsh (depends on constants, utils)
       ↓
mode-manager.zsh (depends on constants, utils)
       ↓
editor.zsh (depends on constants, utils, mode-manager)
       ↓
[Other modules depend on constants, utils, and/or mode-manager]
       ↓
init.zsh (depends on all other modules)
```

## Adding New Functionality

When adding new features:

1. **If it's configuration-related**: Add to `lib/constants.zsh`
2. **If it's a helper function**: Add to `lib/utils.zsh`
3. **If it's a text operation**: Add to `lib/editor.zsh`
4. **If it's mode-related**: Add to `lib/mode-manager.zsh`
5. **If it's keybinding setup**: Add to `lib/keybindings.zsh` or `lib/init.zsh`
6. **For specialized features**: Create a new module file

## Modifying Existing Code

To modify an existing function or constant:

1. Locate it in the appropriate module (see descriptions above)
2. Edit that module file
3. The changes will be loaded automatically when the plugin is sourced

## Performance Considerations

- Module loading is sequential but minimal overhead
- All modules are sourced once at plugin initialization
- No lazy-loading of modules (they're all small enough)
- Keybindings can be lazily loaded via `ZVM_LAZY_KEYBINDINGS`

## Backward Compatibility

All function and variable names remain unchanged. The modular structure is purely organizational and doesn't affect:
- User configuration
- Plugin API
- Keybinding customization
- Command execution
