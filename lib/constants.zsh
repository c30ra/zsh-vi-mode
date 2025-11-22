# Constants and configuration for zsh-vi-mode
# This module contains all constant definitions and default settings

# Plugin information
typeset -gr ZVM_NAME='zsh-vi-mode'
typeset -gr ZVM_DESCRIPTION='💻 A better and friendly vi(vim) mode plugin for ZSH.'
typeset -gr ZVM_REPOSITORY='https://github.com/jeffreytse/zsh-vi-mode'
typeset -gr ZVM_VERSION='0.12.0'

# Plugin initial status
ZVM_INIT_DONE=false

# Postpone reset prompt (i.e. postpone the widget `reset-prompt`)
# -1 (No postponing)
# >=0 (Postponing, the decimal value stands for calling times of `reset-prompt`)
ZVM_POSTPONE_RESET_PROMPT=-1

# Disable reset prompt (i.e. postpone the widget `reset-prompt`)
ZVM_RESET_PROMPT_DISABLED=false

# Operator pending mode
ZVM_OPPEND_MODE=false

# Insert mode could be
# `i` (insert)
# `a` (append)
# `I` (insert at the non-blank beginning of current line)
# `A` (append at the end of current line)
ZVM_INSERT_MODE='i'

# The mode could be the below value:
# `n` (normal)
# `i` (insert)
# `v` (visual)
# `vl` (visual-line)
ZVM_MODE=''

# The keys typed to invoke this widget, as a literal string
ZVM_KEYS=''

# The region hilight information
ZVM_REGION_HIGHLIGHT=()

# Default zvm readkey engines
ZVM_READKEY_ENGINE_NEX='nex'
ZVM_READKEY_ENGINE_ZLE='zle'
ZVM_READKEY_ENGINE_DEFAULT=$ZVM_READKEY_ENGINE_NEX

# Default alternative character for escape characters
ZVM_ESCAPE_SPACE='\s'
ZVM_ESCAPE_NEWLINE='^J'

# Default vi modes
ZVM_MODE_LAST=''
ZVM_MODE_NORMAL='n'
ZVM_MODE_INSERT='i'
ZVM_MODE_VISUAL='v'
ZVM_MODE_VISUAL_LINE='vl'
ZVM_MODE_REPLACE='r'

# Default cursor styles
ZVM_CURSOR_USER_DEFAULT='ud'
ZVM_CURSOR_BLOCK='bl'
ZVM_CURSOR_UNDERLINE='ul'
ZVM_CURSOR_BEAM='be'
ZVM_CURSOR_BLINKING_BLOCK='bbl'
ZVM_CURSOR_BLINKING_UNDERLINE='bul'
ZVM_CURSOR_BLINKING_BEAM='bbe'

# The commands need to be repeated
ZVM_REPEAT_MODE=false
ZVM_REPEAT_RESET=false
ZVM_REPEAT_COMMANDS=($ZVM_MODE_NORMAL i)

# Range handling return values
ZVM_RANGE_HANDLER_RET_OK=0
ZVM_RANGE_HANDLER_RET_CONTINUE=1
ZVM_RANGE_HANDLER_RET_PUSHBACK=2
ZVM_RANGE_HANDLER_RET_CANCEL=3

# URL regex pattern
ZVM_URL_SCHEME='^(http(s)?:\/\/.)?(ftp(s)?:\/\/.)?(file:\/\/.)?(www\.)?'
ZVM_URL_HOST='[-a-zA-Z0-9@:%._\+~#=]{0,255}\.[a-z]{2,6}'
ZVM_URL_PATH='([-a-zA-Z0-9@:%_\+.~#?&\/=]*)$'
ZVM_URL_REGEX="${ZVM_URL_SCHEME}${ZVM_URL_HOST}${ZVM_URL_PATH}"

##########################################
# Initialize all default settings

# Default config function
: ${ZVM_CONFIG_FUNC:='zvm_config'}

# Set the readkey engine (default is NEX engine)
: ${ZVM_READKEY_ENGINE:=$ZVM_READKEY_ENGINE_DEFAULT}

# Set key input timeout (default is 0.4 seconds)
: ${ZVM_KEYTIMEOUT:=0.4}

# Set the escape key timeout (default is 0.03 seconds)
: ${ZVM_ESCAPE_KEYTIMEOUT:=0.03}

# Set keybindings mode (default is true)
# The lazy keybindings will post the keybindings of vicmd and visual
# keymaps to the first time entering the normal mode
: ${ZVM_LAZY_KEYBINDINGS:=true}

# All keybindings for lazy loading
if $ZVM_LAZY_KEYBINDINGS; then
  ZVM_LAZY_KEYBINDINGS_LIST=()
fi

# Set the cursor style in different vi modes
: ${ZVM_INSERT_MODE_CURSOR:=$ZVM_CURSOR_BEAM}
: ${ZVM_NORMAL_MODE_CURSOR:=$ZVM_CURSOR_BLOCK}
: ${ZVM_VISUAL_MODE_CURSOR:=$ZVM_CURSOR_BLOCK}
: ${ZVM_VISUAL_LINE_MODE_CURSOR:=$ZVM_CURSOR_BLOCK}

# Operator pending mode cursor style (default is underscore)
: ${ZVM_OPPEND_MODE_CURSOR:=$ZVM_CURSOR_UNDERLINE}

# Set the vi escape key (default is ^[ => <ESC>)
: ${ZVM_VI_ESCAPE_BINDKEY:=^[}
: ${ZVM_VI_INSERT_ESCAPE_BINDKEY:=$ZVM_VI_ESCAPE_BINDKEY}
: ${ZVM_VI_VISUAL_ESCAPE_BINDKEY:=$ZVM_VI_ESCAPE_BINDKEY}
: ${ZVM_VI_OPPEND_ESCAPE_BINDKEY:=$ZVM_VI_ESCAPE_BINDKEY}

# Set the line init mode (empty will keep the last mode)
: ${ZVM_LINE_INIT_MODE:=$ZVM_MODE_LAST}

# Default init mode when sourcing/loading the plugin
: ${ZVM_INIT_MODE:=sourcing}

: ${ZVM_VI_INSERT_MODE_LEGACY_UNDO:=false}
: ${ZVM_VI_SURROUND_BINDKEY:=classic}
: ${ZVM_VI_HIGHLIGHT_BACKGROUND:=#cc0000}
: ${ZVM_VI_HIGHLIGHT_FOREGROUND:=#eeeeee}
: ${ZVM_VI_HIGHLIGHT_EXTRASTYLE:=default}
: ${ZVM_VI_EDITOR:=${EDITOR:-vim}}
: ${ZVM_TMPDIR:=${TMPDIR:-/tmp}}

# Set the term for handling terminal sequences
: ${ZVM_TERM:=${TERM:-xterm-256color}}

# Enable the cursor style feature
: ${ZVM_CURSOR_STYLE_ENABLED:=true}

# Enable system clipboard feature
: ${ZVM_SYSTEM_CLIPBOARD_ENABLED:=false}
: ${ZVM_CLIPBOARD_COPY_CMD:=}
: ${ZVM_CLIPBOARD_PASTE_CMD:=}

# Open URL or file path feature
: ${ZVM_OPEN_CMD:=}
: ${ZVM_OPEN_URL_CMD:=${ZVM_OPEN_CMD:-}}
: ${ZVM_OPEN_FILE_CMD:=${ZVM_OPEN_CMD:-}}

# All the extra commands
commands_array_names=(
  zvm_before_init_commands
  zvm_after_init_commands
  zvm_before_select_vi_mode_commands
  zvm_after_select_vi_mode_commands
  zvm_before_lazy_keybindings_commands
  zvm_after_lazy_keybindings_commands
)
for commands_array_name in $commands_array_names; do
  # Use typeset -p to check existence of the variable safely (avoids unbound parameter errors
  # when the caller uses `set -u`). If not present, declare it as a global array.
  if ! typeset -p "$commands_array_name" >/dev/null 2>&1; then
    typeset -g -a "$commands_array_name"
  fi
done

# All the handlers for switching keyword
zvm_switch_keyword_handlers=(
  zvm_switch_number
  zvm_switch_boolean
  zvm_switch_operator
  zvm_switch_weekday
  zvm_switch_month
)

# History for switching keyword
zvm_switch_keyword_history=()
