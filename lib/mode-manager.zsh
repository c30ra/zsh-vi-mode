# Mode management for zsh-vi-mode
# Handles switching between VI modes (normal, insert, visual, etc.)

# Enter the visual mode
function zvm_enter_visual_mode() {
  local mode=
  local last_mode=$ZVM_MODE
  local last_region=

  case $last_mode in
    $ZVM_MODE_VISUAL|$ZVM_MODE_VISUAL_LINE)
      last_region=($MARK $CURSOR)
      zvm_exit_visual_mode
      ;;
  esac

  case "${1:-$(zvm_keys)}" in
    v) mode=$ZVM_MODE_VISUAL;;
    V) mode=$ZVM_MODE_VISUAL_LINE;;
    *) mode=$last_mode;;
  esac

  if [[ $last_mode == $mode ]]; then
    return
  fi

  zvm_select_vi_mode $mode

  if [[ -n $last_region ]]; then
    MARK=$last_region[1]
    CURSOR=$last_region[2]
    zle redisplay
  fi
}

# Exit the visual mode
function zvm_exit_visual_mode() {
  case "$ZVM_MODE" in
    $ZVM_MODE_VISUAL) zle visual-mode;;
    $ZVM_MODE_VISUAL_LINE) zle visual-line-mode;;
  esac
  zvm_highlight clear
  zvm_select_vi_mode $ZVM_MODE_NORMAL ${1:-true}
}

# Enter the vi insert mode
function zvm_enter_insert_mode() {
  local keys=${1:-$(zvm_keys)}

  if [[ $keys == 'i' ]]; then
    ZVM_INSERT_MODE='i'
  elif [[ $keys == 'a' ]]; then
    ZVM_INSERT_MODE='a'
    if ! zvm_is_empty_line; then
      CURSOR=$((CURSOR+1))
    fi
  fi

  zvm_reset_repeat_commands $ZVM_MODE_NORMAL $ZVM_INSERT_MODE
  zvm_select_vi_mode $ZVM_MODE_INSERT
}

# Exit the vi insert mode
function zvm_exit_insert_mode() {
  ZVM_INSERT_MODE=
  zvm_select_vi_mode $ZVM_MODE_NORMAL ${1:-true}
}

# Enter the vi operator pending mode
function zvm_enter_oppend_mode() {
  ZVM_OPPEND_MODE=true
  ${1:-true} && zvm_update_cursor
}

# Exit the vi operator pending mode
function zvm_exit_oppend_mode() {
  ZVM_OPPEND_MODE=false
  ${1:-true} && zvm_update_cursor
}

# Insert at the beginning of the line
function zvm_insert_bol() {
  ZVM_INSERT_MODE='I'
  zle vi-first-non-blank
  zvm_exit_visual_mode false
  zvm_select_vi_mode $ZVM_MODE_INSERT
  zvm_reset_repeat_commands $ZVM_MODE_NORMAL $ZVM_INSERT_MODE
}

# Append at the end of the line
function zvm_append_eol() {
  ZVM_INSERT_MODE='A'
  zle vi-end-of-line
  zvm_exit_visual_mode false
  zvm_select_vi_mode $ZVM_MODE_INSERT
  zvm_reset_repeat_commands $ZVM_MODE_NORMAL $ZVM_INSERT_MODE
}

# Self insert content to cursor position
function zvm_self_insert() {
  local keys=${1:-$KEYS}

  if [[ ${POSTDISPLAY:0:$#keys} == $keys ]]; then
    POSTDISPLAY=${POSTDISPLAY:$#keys}
  else
    POSTDISPLAY=
  fi

  LBUFFER+=${keys}
}

# Reset the repeat commands
function zvm_reset_repeat_commands() {
  ZVM_REPEAT_RESET=true
  ZVM_REPEAT_COMMANDS=($@)
}

# Select vi mode
function zvm_select_vi_mode() {
  local mode=$1
  local reset_prompt=${2:-true}

  if [[ $mode == "$ZVM_MODE" ]]; then
    zvm_update_cursor
    return
  fi

  zvm_exec_commands 'before_select_vi_mode'

  zvm_postpone_reset_prompt true

  if $ZVM_OPPEND_MODE; then
    zvm_exit_oppend_mode false
  fi

  case $mode in
    $ZVM_MODE_NORMAL)
      ZVM_MODE=$ZVM_MODE_NORMAL
      zvm_update_cursor
      zle vi-cmd-mode
      ;;
    $ZVM_MODE_INSERT)
      ZVM_MODE=$ZVM_MODE_INSERT
      zvm_update_cursor
      zle vi-insert
      ;;
    $ZVM_MODE_VISUAL)
      ZVM_MODE=$ZVM_MODE_VISUAL
      zvm_update_cursor
      zle visual-mode
      ;;
    $ZVM_MODE_VISUAL_LINE)
      ZVM_MODE=$ZVM_MODE_VISUAL_LINE
      zvm_update_cursor
      zle visual-line-mode
      ;;
    $ZVM_MODE_REPLACE)
      ZVM_MODE=$ZVM_MODE_REPLACE
      zvm_enter_oppend_mode
      ;;
  esac

  zvm_exec_commands 'after_select_vi_mode'

  $reset_prompt && zvm_postpone_reset_prompt false true

  if [[ $mode == $ZVM_MODE_NORMAL ]] &&
    (( $#ZVM_LAZY_KEYBINDINGS_LIST > 0 )); then

    zvm_exec_commands 'before_lazy_keybindings'

    local list=("${ZVM_LAZY_KEYBINDINGS_LIST[@]}")
    unset ZVM_LAZY_KEYBINDINGS_LIST

    for r in "${list[@]}"; do
      eval "zvm_bindkey ${r}"
    done

    zvm_exec_commands 'after_lazy_keybindings'
  fi
}

# Postpone reset prompt
function zvm_postpone_reset_prompt() {
  local toggle=$1
  local force=${2:-false}

  if $force; then
    ZVM_POSTPONE_RESET_PROMPT=1
  fi

  if $toggle; then
    ZVM_POSTPONE_RESET_PROMPT=0
  else
    if (($ZVM_POSTPONE_RESET_PROMPT > 0)); then
      ZVM_POSTPONE_RESET_PROMPT=-1
      zle reset-prompt
    else
      ZVM_POSTPONE_RESET_PROMPT=-1
    fi
  fi
}

# Reset prompt
function zvm_reset_prompt() {
  if (($ZVM_POSTPONE_RESET_PROMPT >= 0)); then
    ZVM_POSTPONE_RESET_PROMPT=$(($ZVM_POSTPONE_RESET_PROMPT + 1))
    return
  fi
  if [[ $ZVM_RESET_PROMPT_DISABLED == true ]]; then
    return
  fi
  local -i retval=0
  if [[ -z "$rawfunc" ]]; then
    zle .reset-prompt -- "$@"
    retval=$?
  else
    $rawfunc -- "$@"
    retval=$?
  fi
  return $retval
}

# Undo action in vi insert mode
function zvm_viins_undo() {
  if $ZVM_VI_INSERT_MODE_LEGACY_UNDO; then
    zvm_kill_line
  else
    zvm_backward_kill_line
  fi
}
