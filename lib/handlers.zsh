# handlers.zsh - Event handlers for VI mode
# Handles key input processing and default event handling

# Default handler for unbound keys
# Processes unbound keys based on current VI mode (normal, insert, visual)
# Handles character insertion, escaping, and mode transitions
function zvm_default_handler() {
  local keys=$(zvm_keys)
  local extra_keys=$1

  # Exit vi mode if keys is the escape keys
  case $(zvm_escape_non_printed_characters "$keys") in
    '^['|$ZVM_VI_INSERT_ESCAPE_BINDKEY)
      zvm_exit_insert_mode false
      zvm_reset_prompt
      ZVM_KEYS=${extra_keys}
      return
      ;;
    [vV]'^['|[vV]$ZVM_VI_VISUAL_ESCAPE_BINDKEY)
      zvm_exit_visual_mode false
      zvm_reset_prompt
      ZVM_KEYS=${extra_keys}
      return
      ;;
  esac

  case "$KEYMAP" in
    vicmd)
      case "$keys" in
        [vV]c) zvm_vi_change false;;
        [vV]d) zvm_vi_delete false;;
        [vV]y) zvm_vi_yank false;;
        [vV]S) zvm_change_surround S;;
        [cdyvV]*)
          # We must loop util we meet a valid range action
          while :; do
            zvm_range_handler "${keys}${extra_keys}"
            case $? in
              $ZVM_RANGE_HANDLER_RET_OK)
                # The range action is handled successfully and exit
                break
                ;;
              $ZVM_RANGE_HANDLER_RET_CONTINUE)
                # Continue to ask to provide the action when we're
                # still in visual mode
                keys='v'; extra_keys=
                ;;
              $ZVM_RANGE_HANDLER_RET_PUSHBACK)
                # Push the keys onto the input stack of ZLE, it's
                # handled in zvm_readkeys_handler function
                zvm_exit_visual_mode false
                zvm_reset_prompt
                return
                ;;
              $ZVM_RANGE_HANDLER_RET_CANCEL)
                # Exit visual mode and cancel the range action
                zvm_exit_visual_mode false
                zvm_reset_prompt
                break
                ;;
            esac
          done
          ;;
        *)
          local i=
          for ((i=0;i<$#keys;i++)) do
            zvm_navigation_handler ${keys:$i:1}
            zvm_highlight
          done
          ;;
      esac
      ;;
    viins|main)
      if [[ "${keys:0:1}" =~ [a-zA-Z0-9\ ] ]]; then
        zvm_self_insert "${keys:0:1}"
        zle redisplay
        ZVM_KEYS="${keys:1}${extra_keys}"
        return
      elif [[ "${keys:0:1}" == $'\e' ]]; then
        zvm_exit_insert_mode false
        ZVM_KEYS="${keys:1}${extra_keys}"
        return
      fi
      ;;
    visual)
      ;;
  esac

  ZVM_KEYS=
}

# Read keys for retrieving and executing a widget
# Routes key input to appropriate widget or default handler based on current VI mode
# Returns appropriate action for the given key sequence
function zvm_readkeys_handler() {
  local keymap=${1}
  local keys=${2:-$KEYS}
  local key=
  local widget=

  # Get the keymap if keymap is empty
  if [[ -z $keymap ]]; then
    case "$ZVM_MODE" in
      $ZVM_MODE_INSERT) keymap=viins;;
      $ZVM_MODE_NORMAL) keymap=vicmd;;
      $ZVM_MODE_VISUAL|$ZVM_MODE_VISUAL_LINE) keymap=visual;;
    esac
  fi

  # Read keys and retrieve the widget
  zvm_readkeys $keymap $keys
  keys=${retval[1]}
  widget=${retval[2]}
  key=${retval[3]}

  # Escape space in keys
  keys=${keys//$ZVM_ESCAPE_SPACE/ }
  key=${key//$ZVM_ESCAPE_SPACE/ }

  ZVM_KEYS="${keys}"

  # If the widget is current handler, we should call the default handler
  if [[ "${widget}" == "${funcstack[1]}" ]]; then
    widget=
  fi

  # If the widget isn't matched, we should call the default handler
  if [[ -z ${widget} ]]; then
    # Disable reset prompt action, as multiple calling this function
    # will cause potential line eaten issue.
    ZVM_RESET_PROMPT_DISABLED=true

    zle zvm_default_handler "$key"

    ZVM_RESET_PROMPT_DISABLED=false

    # Push back to the key input stack, and postpone reset prompt
    if [[ -n "$ZVM_KEYS" ]]; then
      # To prevent ZLE from error "not enough arguments for -U", the
      # parameter should be put after `--` symbols.
      zle -U -- "${ZVM_KEYS}"
    else
      # If there is any reset prompt, we need to execute for
      # prompt resetting.
      zvm_postpone_reset_prompt false
    fi
  else
    zle $widget
  fi

  ZVM_KEYS=
}
