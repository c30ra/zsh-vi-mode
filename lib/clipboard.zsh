# clipboard.zsh - System clipboard integration
# Copy/paste operations with system clipboard support

# Detect available clipboard command
# Auto-detects clipboard tools (pbcopy, wl-copy, xclip, xsel)
function zvm_clipboard_detect() {
  if zvm_exist_command pbcopy && zvm_exist_command pbpaste; then
    ZVM_CLIPBOARD_COPY_CMD='pbcopy'
    ZVM_CLIPBOARD_PASTE_CMD='pbpaste'
    return
  fi
  if zvm_exist_command wl-copy && zvm_exist_command wl-paste; then
    ZVM_CLIPBOARD_COPY_CMD='wl-copy'
    ZVM_CLIPBOARD_PASTE_CMD='wl-paste -n'
    return
  fi
  if zvm_exist_command xclip; then
    ZVM_CLIPBOARD_COPY_CMD='xclip -selection clipboard'
    ZVM_CLIPBOARD_PASTE_CMD='xclip -selection clipboard -o'
    return
  fi
  if zvm_exist_command xsel; then
    ZVM_CLIPBOARD_COPY_CMD='xsel --clipboard -i'
    ZVM_CLIPBOARD_PASTE_CMD='xsel --clipboard -o'
    return
  fi
}

# Check if clipboard is available
# Returns 0 if clipboard tools are available, 1 otherwise
function zvm_clipboard_available() {
  zvm_clipboard_detect
  if [[ -n $ZVM_CLIPBOARD_COPY_CMD && -n $ZVM_CLIPBOARD_PASTE_CMD ]]; then
    return 0
  fi
  return 1
}

# Copy CUTBUFFER to system clipboard
# Copies the current cut/yank buffer to system clipboard
function zvm_clipboard_copy_buffer() {
  $ZVM_SYSTEM_CLIPBOARD_ENABLED || return
  zvm_clipboard_available || return
  print -rn -- "$CUTBUFFER" | eval "$ZVM_CLIPBOARD_COPY_CMD" >/dev/null 2>&1
}

# Get content from system clipboard
# Retrieves text from system clipboard
function zvm_clipboard_get() {
  zvm_clipboard_available || return
  eval "$ZVM_CLIPBOARD_PASTE_CMD" 2>/dev/null
}

# Paste content from system clipboard after cursor
# Pastes clipboard content after cursor position (gp command)
function zvm_paste_clipboard_after() {
  local content=$(zvm_clipboard_get)
  [[ -z $content ]] && return
  local saved=$CUTBUFFER
  CUTBUFFER=$content
  zvm_vi_put_after
  CUTBUFFER=$saved
}

# Paste content from system clipboard before cursor
# Pastes clipboard content before cursor position (gP command)
function zvm_paste_clipboard_before() {
  local content=$(zvm_clipboard_get)
  [[ -z $content ]] && return
  local saved=$CUTBUFFER
  CUTBUFFER=$content
  zvm_vi_put_before
  CUTBUFFER=$saved
}

# Paste content from system clipboard in visual mode
# Replaces visual selection with clipboard content (gp/gP in visual)
function zvm_visual_paste_clipboard() {
  local content=$(zvm_clipboard_get)
  if [[ -z $content ]]; then
    zvm_exit_visual_mode
    return
  fi
  local ret=($(zvm_calc_selection))
  local bpos=$ret[1] epos=$ret[2]
  local cpos=$((bpos + $#content - 1))
  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}
  BUFFER="${BUFFER:0:$bpos}${content}${BUFFER:$epos}"
  CURSOR=$cpos
  zvm_exit_visual_mode
}
