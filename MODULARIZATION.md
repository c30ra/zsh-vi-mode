# ZSH VI Mode - Modular Refactoring Guide

## Overview

The `zsh-vi-mode` plugin has been reorganized into maintainable modules for easier development and maintenance.

## Current Status

✅ **Completed Modules:**
- `lib/constants.zsh` - All global constants and configuration
- `lib/utils.zsh` - Utility helper functions
- `lib/mode-manager.zsh` - VI mode management

⏳ **To Be Completed:**
- `lib/keybindings.zsh` - Keybinding setup and key reading
- `lib/editor.zsh` - Text editing operations
- `lib/repeat.zsh` - Repeat command functionality
- `lib/surround.zsh` - Surround text objects
- `lib/keywords.zsh` - Keyword switching
- `lib/ui.zsh` - Cursor and highlighting
- `lib/clipboard.zsh` - Clipboard integration
- `lib/url.zsh` - URL/path opening
- `lib/navigation.zsh` - Navigation commands
- `lib/handlers.zsh` - Event handlers
- `lib/zle-hooks.zsh` - ZLE lifecycle hooks
- `lib/init.zsh` - Initialization logic

## How to Complete the Refactoring

### Step 1: Extract Function Groups

For each remaining module, extract the related functions from `zsh-vi-mode.zsh` and place them in the corresponding `lib/*.zsh` file.

**Example for `lib/editor.zsh`:**
```bash
# Extract these functions:
- zvm_backward_kill_region()
- zvm_backward_kill_line()
- zvm_forward_kill_line()
- zvm_kill_line()
- zvm_kill_whole_line()
- zvm_vi_replace()
- zvm_vi_delete()
- zvm_vi_yank()
- ... etc
```

### Step 2: Extract `lib/init.zsh`

This is the most critical module. Extract the `zvm_init()` function and all widget/keybinding setup code. This includes:

- Widget registration (zvm_define_widget calls)
- All keybinding setup (zvm_bindkey calls)
- ZLE hook setup
- Any initialization logic

### Step 3: Update Loader

Once all modules are created, update `lib/loader.zsh` to source them properly. The loader should:

1. Check for module existence
2. Load in dependency order
3. Source the configuration
4. Call initialization

### Step 4: Create Init Module

The `lib/init.zsh` should contain:
- The main `zvm_init()` function
- All widget and keybinding setup
- Any setup logic

### Step 5: Maintain Backward Compatibility

The original `zsh-vi-mode.zsh` should be kept as-is for now and renamed to `zsh-vi-mode-monolithic.zsh` as a fallback reference.

## Function Grouping Reference

### `lib/keybindings.zsh`
```
zvm_find_bindkey_widget()
zvm_readkeys()
zvm_bindkey()
```

### `lib/navigation.zsh`
```
zvm_find_and_move_cursor()
zvm_navigation_handler()
zvm_range_handler()
```

### `lib/handlers.zsh`
```
zvm_default_handler()
zvm_readkeys_handler()
```

### `lib/editor.zsh`
```
zvm_backward_kill_region()
zvm_backward_kill_line()
zvm_forward_kill_line()
zvm_kill_line()
zvm_kill_whole_line()
zvm_vi_replace()
zvm_vi_replace_chars()
zvm_vi_substitute()
zvm_vi_substitute_whole_line()
zvm_calc_selection()
zvm_yank()
zvm_vi_up_case()
zvm_vi_down_case()
zvm_vi_opp_case()
zvm_vi_yank()
zvm_vi_put_after()
zvm_vi_put_before()
zvm_replace_selection()
zvm_vi_replace_selection()
zvm_vi_delete()
zvm_vi_change()
zvm_vi_change_eol()
```

### `lib/repeat.zsh`
```
zvm_repeat_command()
zvm_repeat_change()
zvm_repeat_insert()
zvm_repeat_vi_change()
zvm_repeat_range_change()
zvm_repeat_replace()
zvm_repeat_replace_chars()
```

### `lib/surround.zsh`
```
zvm_parse_surround_keys()
zvm_move_around_surround()
zvm_match_surround()
zvm_search_surround()
zvm_select_surround()
zvm_change_surround()
zvm_change_surround_text_object()
```

### `lib/keywords.zsh`
```
zvm_switch_keyword()
zvm_switch_number()
zvm_switch_boolean()
zvm_switch_weekday()
zvm_switch_operator()
zvm_switch_month()
```

### `lib/ui.zsh`
```
zvm_highlight()
zvm_set_cursor()
zvm_cursor_style()
zvm_update_cursor()
zvm_update_highlight()
zvm_update_repeat_commands()
```

### `lib/clipboard.zsh`
```
zvm_clipboard_detect()
zvm_clipboard_available()
zvm_clipboard_copy_buffer()
zvm_clipboard_get()
zvm_paste_clipboard_after()
zvm_paste_clipboard_before()
zvm_visual_paste_clipboard()
```

### `lib/url.zsh`
```
zvm_select_url_or_path()
zvm_open_under_cursor()
zvm_vi_edit_command_line()
```

### `lib/zle-hooks.zsh`
```
zvm_zle-line-pre-redraw()
zvm_zle-line-init()
zvm_zle-line-finish()
```

## Testing

After extracting each module:

1. **Test individual module loading:**
   ```bash
   source lib/constants.zsh
   source lib/utils.zsh
   source lib/mode-manager.zsh
   ```

2. **Test with plugin:**
   ```bash
   # In .zshrc
   source /path/to/zsh-vi-mode/lib/loader.zsh
   ```

3. **Verify functionality:**
   - VI mode switching works
   - Keys are properly bound
   - All operations function correctly

## Benefits of Modularization

- **Easier maintenance:** Related functionality is grouped together
- **Better readability:** Files are shorter and focused
- **Simpler debugging:** Isolate issues to specific modules
- **Easier testing:** Each module can be tested independently
- **Better collaboration:** Multiple developers can work on different modules
- **More scalable:** New features can be added in dedicated modules

## Next Steps

1. Create remaining module files
2. Test each module independently
3. Test integrated loading
4. Update documentation with new module structure
5. Consider adding module dependency management
6. Plan for potential lazy-loading of modules
