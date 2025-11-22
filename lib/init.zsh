# init.zsh - Initialization and widget/keybinding setup
# Main initialization function and ZLE lifecycle hooks

# Updates editor information when line pre redraw
# Handles cursor style and highlight updates in special terminal environments
function zvm_zle-line-pre-redraw() {
  # Fix cursor style is not updated in tmux environment, when
  # there are one more panel in the same window, the program
  # in other panel could change the cursor shape, we need to
  # update cursor style when line is redrawing.
  if [[ -n $TMUX ]]; then
    zvm_update_cursor
    # Fix display is not updated in the terminal of IntelliJ IDE.
    [[ "$TERMINAL_EMULATOR" == "JetBrains-JediTerm" ]] && zle redisplay
  fi
  zvm_update_highlight
  zvm_update_repeat_commands
}

# Start every prompt in the correct vi mode
# Initializes VI mode for each new command line
function zvm_zle-line-init() {
  # Save last mode
  local mode=${ZVM_MODE:-$ZVM_MODE_INSERT}

  # It's neccessary to set to insert mode when line init
  # and we don't need to reset prompt.
  zvm_select_vi_mode $ZVM_MODE_INSERT false

  # Select line init mode and reset prompt
  case ${ZVM_LINE_INIT_MODE:-$mode} in
    $ZVM_MODE_INSERT) zvm_select_vi_mode $ZVM_MODE_INSERT;;
    *) zvm_select_vi_mode $ZVM_MODE_NORMAL;;
  esac
}

# Restore the user default cursor style after prompt finish
# Manages cursor style when executing commands or interactive programs
function zvm_zle-line-finish() {
  # When we start a program (e.g. vim, bash, etc.) from the
  # command line, the cursor style is inherited by other
  # programs, so that we need to reset the cursor style to
  # default before executing a command and set the custom
  # style again when the command exits. This way makes any
  # other interactive CLI application would not be affected
  # by it.
  local shape=$(zvm_cursor_style $ZVM_CURSOR_USER_DEFAULT)
  zvm_set_cursor $shape
  zvm_switch_keyword_history=()
}

# Initialize vi-mode for widgets, keybindings, etc.
# Main initialization function that sets up all VI mode functionality
function zvm_init() {
  # Check if it has been initalized
  if $ZVM_INIT_DONE; then
    return;
  fi

  # Mark plugin initial status
  ZVM_INIT_DONE=true

  zvm_exec_commands 'before_init'

  # Correct the readkey engine
  case $ZVM_READKEY_ENGINE in
    $ZVM_READKEY_ENGINE_NEX|$ZVM_READKEY_ENGINE_ZLE);;
    *)
      echo -n "Warning: Unsupported readkey engine! "
      echo "ZVM_READKEY_ENGINE=$ZVM_READKEY_ENGINE"
      ZVM_READKEY_ENGINE=$ZVM_READKEY_ENGINE_DEFAULT
      ;;
  esac

  # Reduce ESC delay (zle default is 0.4 seconds)
  # Set to 0.01 second delay for taking over the key input processing
  case $ZVM_READKEY_ENGINE in
    $ZVM_READKEY_ENGINE_NEX) KEYTIMEOUT=1;;
    $ZVM_READKEY_ENGINE_ZLE) KEYTIMEOUT=$(($ZVM_KEYTIMEOUT*100));;
  esac

  # Create User-defined widgets
  zvm_define_widget zvm_default_handler
  zvm_define_widget zvm_readkeys_handler
  zvm_define_widget zvm_backward_kill_region
  zvm_define_widget zvm_backward_kill_line
  zvm_define_widget zvm_forward_kill_line
  zvm_define_widget zvm_kill_line
  zvm_define_widget zvm_viins_undo
  zvm_define_widget zvm_select_surround
  zvm_define_widget zvm_change_surround
  zvm_define_widget zvm_move_around_surround
  zvm_define_widget zvm_change_surround_text_object
  zvm_define_widget zvm_enter_insert_mode
  zvm_define_widget zvm_exit_insert_mode
  zvm_define_widget zvm_enter_visual_mode
  zvm_define_widget zvm_exit_visual_mode
  zvm_define_widget zvm_enter_oppend_mode
  zvm_define_widget zvm_exit_oppend_mode
  zvm_define_widget zvm_exchange_point_and_mark
  zvm_define_widget zvm_open_line_below
  zvm_define_widget zvm_open_line_above
  zvm_define_widget zvm_insert_bol
  zvm_define_widget zvm_append_eol
  zvm_define_widget zvm_self_insert
  zvm_define_widget zvm_vi_replace
  zvm_define_widget zvm_vi_replace_chars
  zvm_define_widget zvm_vi_substitute
  zvm_define_widget zvm_vi_substitute_whole_line
  zvm_define_widget zvm_vi_change
  zvm_define_widget zvm_vi_change_eol
  zvm_define_widget zvm_vi_delete
  zvm_define_widget zvm_vi_yank
  zvm_define_widget zvm_vi_put_after
  zvm_define_widget zvm_vi_put_before
  zvm_define_widget zvm_vi_replace_selection
  zvm_define_widget zvm_vi_up_case
  zvm_define_widget zvm_vi_down_case
  zvm_define_widget zvm_vi_opp_case
  zvm_define_widget zvm_vi_edit_command_line
  zvm_define_widget zvm_repeat_change
  zvm_define_widget zvm_switch_keyword
  zvm_define_widget zvm_paste_clipboard_after
  zvm_define_widget zvm_paste_clipboard_before
  zvm_define_widget zvm_visual_paste_clipboard

  # Open URL under cursor
  zvm_define_widget zvm_open_under_cursor

  # Override standard widgets
  zvm_define_widget zle-line-pre-redraw zvm_zle-line-pre-redraw

  # Ensure the correct cursor style when an interactive program
  # (e.g. vim, bash, etc.) starts and exits
  zvm_define_widget zle-line-init zvm_zle-line-init
  zvm_define_widget zle-line-finish zvm_zle-line-finish

  # Override reset-prompt widget
  zvm_define_widget reset-prompt zvm_reset_prompt

  # All Key bindings
  # Emacs-like bindings
  # Normal editing
  zvm_bindkey viins '^A' beginning-of-line
  zvm_bindkey viins '^E' end-of-line
  zvm_bindkey viins '^B' backward-char
  zvm_bindkey viins '^F' forward-char
  zvm_bindkey viins '^K' zvm_forward_kill_line
  zvm_bindkey viins '^W' backward-kill-word
  zvm_bindkey viins '^U' zvm_viins_undo
  zvm_bindkey viins '^Y' yank
  zvm_bindkey viins '^_' undo

  # Mode agnostic editing
  zvm_bindkey viins '^[[H'  beginning-of-line
  zvm_bindkey vicmd '^[[H'  beginning-of-line
  zvm_bindkey viins '^[[F'  end-of-line
  zvm_bindkey vicmd '^[[F'  end-of-line
  zvm_bindkey viins '^[[3~' delete-char
  zvm_bindkey vicmd '^[[3~' delete-char

  # Line history navigation
  zvm_bindkey viins '^P' up-line-or-history
  zvm_bindkey viins '^N' down-line-or-history

  # Insert mode
  zvm_bindkey vicmd 'i'  zvm_enter_insert_mode
  zvm_bindkey vicmd 'a'  zvm_enter_insert_mode
  zvm_bindkey vicmd 'I'  zvm_insert_bol
  zvm_bindkey vicmd 'A'  zvm_append_eol

  # Other key bindings
  zvm_bindkey vicmd  'v' zvm_enter_visual_mode
  zvm_bindkey vicmd  'V' zvm_enter_visual_mode
  zvm_bindkey visual 'o' zvm_exchange_point_and_mark
  zvm_bindkey vicmd  'o' zvm_open_line_below
  zvm_bindkey vicmd  'O' zvm_open_line_above
  zvm_bindkey vicmd  'r' zvm_vi_replace_chars
  zvm_bindkey vicmd  'R' zvm_vi_replace
  zvm_bindkey vicmd  's' zvm_vi_substitute
  zvm_bindkey vicmd  'S' zvm_vi_substitute_whole_line
  zvm_bindkey vicmd  'C' zvm_vi_change_eol
  zvm_bindkey visual 'c' zvm_vi_change
  zvm_bindkey visual 'd' zvm_vi_delete
  zvm_bindkey visual 'x' zvm_vi_delete
  zvm_bindkey visual 'y' zvm_vi_yank
  zvm_bindkey vicmd  'p' zvm_vi_put_after
  zvm_bindkey vicmd  'P' zvm_vi_put_before
  zvm_bindkey visual 'p' zvm_vi_replace_selection
  zvm_bindkey visual 'P' zvm_vi_replace_selection
  zvm_bindkey visual 'U' zvm_vi_up_case
  zvm_bindkey visual 'u' zvm_vi_down_case
  zvm_bindkey visual '~' zvm_vi_opp_case
  zvm_bindkey visual 'v' zvm_vi_edit_command_line
  zvm_bindkey vicmd  '.' zvm_repeat_change

  # Open URL under cursor
  zvm_bindkey vicmd 'gx' zvm_open_under_cursor

  # Clipboard support
  zvm_bindkey vicmd  'gp' zvm_paste_clipboard_after
  zvm_bindkey vicmd  'gP' zvm_paste_clipboard_before
  zvm_bindkey visual 'gp' zvm_visual_paste_clipboard
  zvm_bindkey visual 'gP' zvm_visual_paste_clipboard

  # Switch keyword
  zvm_bindkey vicmd '^A' zvm_switch_keyword
  zvm_bindkey vicmd '^X' zvm_switch_keyword

  # Keybindings for escape key and some specials
  local exit_oppend_mode_widget=
  local exit_insert_mode_widget=
  local exit_visual_mode_widget=
  local default_handler_widget=

  case $ZVM_READKEY_ENGINE in
    $ZVM_READKEY_ENGINE_NEX)
      exit_oppend_mode_widget=zvm_readkeys_handler
      exit_insert_mode_widget=zvm_readkeys_handler
      exit_visual_mode_widget=zvm_readkeys_handler
      ;;
    $ZVM_READKEY_ENGINE_ZLE)
      exit_insert_mode_widget=zvm_exit_insert_mode
      exit_visual_mode_widget=zvm_exit_visual_mode
      default_handler_widget=zvm_default_handler
      ;;
  esac

  # Bind custom escape key
  zvm_bindkey vicmd  "$ZVM_VI_OPPEND_ESCAPE_BINDKEY" $exit_oppend_mode_widget
  zvm_bindkey viins  "$ZVM_VI_INSERT_ESCAPE_BINDKEY" $exit_insert_mode_widget
  zvm_bindkey visual "$ZVM_VI_VISUAL_ESCAPE_BINDKEY" $exit_visual_mode_widget

  # Bind the default escape key if the escape key is not the default
  case "$ZVM_VI_OPPEND_ESCAPE_BINDKEY" in
    '^['|'\e') ;;
    *) zvm_bindkey vicmd '^[' $exit_oppend_mode_widget;;
  esac
  case "$ZVM_VI_INSERT_ESCAPE_BINDKEY" in
    '^['|'\e') ;;
    *) zvm_bindkey viins '^[' $exit_insert_mode_widget;;
  esac
  case "$ZVM_VI_VISUAL_ESCAPE_BINDKEY" in
    '^['|'\e') ;;
    *) zvm_bindkey visual '^[' $exit_visual_mode_widget;;
  esac

  # Bind and overwrite original y/d/c of vicmd
  for c in {y,d,c}; do
    zvm_bindkey vicmd "$c" $default_handler_widget
  done

  # Surround text-object
  # Enable surround text-objects (quotes, brackets)
  local surrounds=()

  # Append brackets
  for s in ${(s..)^:-'()[]{}<>'}; do
    surrounds+=($s)
  done

  # Append quotes
  for s in {\',\",\`,\ ,'^['}; do
    surrounds+=($s)
  done

  # Surround key bindings
  for s in $surrounds; do
    for c in {a,i}${s}; do
      zvm_bindkey visual "$c" zvm_select_surround
    done
    for c in {c,d,y}{a,i}${s}; do
      zvm_bindkey vicmd "$c" zvm_change_surround_text_object
    done
    if [[ $ZVM_VI_SURROUND_BINDKEY == 's-prefix' ]]; then
      for c in s{d,r}${s}; do
        zvm_bindkey vicmd "$c" zvm_change_surround
      done
      for c in sa${s}; do
        zvm_bindkey visual "$c" zvm_change_surround
      done
    else
      for c in {d,c}s${s}; do
        zvm_bindkey vicmd "$c" zvm_change_surround
      done
      for c in {S,ys}${s}; do
        zvm_bindkey visual "$c" zvm_change_surround
      done
    fi
  done

  # Moving around surrounds
  zvm_bindkey vicmd '%' zvm_move_around_surround

  # Fix BACKSPACE was stuck in zsh
  # Since normally '^?' (backspace) is bound to vi-backward-delete-char
  zvm_bindkey viins '^?' backward-delete-char

  # Initialize ZVM_MODE value
  case ${ZVM_LINE_INIT_MODE:-$ZVM_MODE_INSERT} in
    $ZVM_MODE_INSERT) ZVM_MODE=$ZVM_MODE_INSERT;;
    *) ZVM_MODE=$ZVM_MODE_NORMAL;;
  esac

  # Enable vi keymap
  bindkey -v

  zvm_exec_commands 'after_init'
}
