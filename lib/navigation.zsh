# navigation.zsh - Navigation and range handling
# VI mode navigation commands and range selection for operations

# Handle the navigation action in normal/visual mode
# Processes navigation commands like hjkl, w, e, b, f, t, G, gg
function zvm_navigation_handler() {
  # Return if no keys provided
  [[ -z $1 ]] && return 1

  local keys=$1
  local count=
  local cmd=

  # Retrieve the calling command
  if [[ $keys =~ '^([1-9][0-9]*)?([fFtT].?)$' ]]; then
    count=${match[1]:-1}

    # The length of keys must be 2
    if (( ${#match[2]} < 2)); then
      zvm_enter_oppend_mode

      read -k 1 cmd
      keys+=$cmd

      case "$(zvm_escape_non_printed_characters ${keys[-1]})" in
        $ZVM_VI_OPPEND_ESCAPE_BINDKEY) return 1;;
      esac

      zvm_exit_oppend_mode
    fi

    local forward=true
    local skip=false

    [[ ${keys[-2]} =~ '[FT]' ]] && forward=false
    [[ ${keys[-2]} =~ '[tT]' ]] && skip=true

    # Escape special characters (e.g. ', ", `, ~, ^, |, &, <space>)
    local key=${keys[-1]}
    if [[ $key =~ "['\\\"\`\~\^\|\#\&\*\;\}\(\)\<\>\ ]" ]]; then
      key=\\${key}
    fi

    cmd=(zvm_find_and_move_cursor $key $count $forward $skip)
    count=1
  # Handle G command
  elif [[ $keys =~ '^([1-9][0-9]*)?G$' ]]; then
    count=${match[1]:-1}
    cmd=(CURSOR=$#BUFFER)
  # Handle gg command
  elif [[ $keys =~ '^([1-9][0-9]*)?gg$' ]]; then
    count=${match[1]:-1}
    cmd=(CURSOR=0)
  else
    count=${keys:0:-1}
    case ${keys: -1} in
      '^') cmd=(zle vi-first-non-blank);;
      '$') cmd=(zle vi-end-of-line);;
      ' ') cmd=(zle vi-forward-char);;
      '0') cmd=(zle vi-digit-or-beginning-of-line);;
      'h') cmd=(zle vi-backward-char);;
      'j') cmd=(zle down-line-or-history);;
      'k') cmd=(zle up-line-or-history);;
      'l') cmd=(zle vi-forward-char);;
      'w') cmd=(zle vi-forward-word);;
      'W') cmd=(zle vi-forward-blank-word);;
      'e') cmd=(zle vi-forward-word-end);;
      'E') cmd=(zle vi-forward-blank-word-end);;
      'b') cmd=(zle vi-backward-word);;
      'B') cmd=(zle vi-backward-blank-word);;
    esac
  fi

  # Check widget if the widget is empty
  if [[ -z $cmd ]]; then
    return 0
  fi

  # Check if keys includes the count
  if [[ ! $count =~ ^[0-9]+$ ]]; then
    count=1
  fi

  zvm_repeat_command "$cmd" $count
  local exit_code=$?

  if [[ $exit_code == 0 ]]; then
    retval=$keys
  fi

  return $exit_code
}

# Handle a range of characters (for c, d, y operations)
# Manages visual mode entry and selection for operator commands
function zvm_range_handler() {
  local keys=$1
  local cursor=$CURSOR
  local key=
  local mode=
  local cmds=($ZVM_MODE)
  local count=1
  local exit_code=$ZVM_RANGE_HANDLER_RET_OK

  # Enter operator pending mode
  zvm_enter_oppend_mode false

  # If the keys is less than 2 keys, we should read more
  # keys (e.g. d, c, y, etc.)
  while (( ${#keys} < 2 )); do
    zvm_update_cursor
    read -k 1 key
    keys="${keys}${key}"
  done

  # If the keys ends in numbers, we should read more
  # keys (e.g. d2, c3, y10, etc.)
  while [[ ${keys: 1} =~ ^[1-9][0-9]*$ ]]; do
    zvm_update_cursor
    read -k 1 key
    keys="${keys}${key}"
  done

  # If the 2nd character is `i` or `a`, we should read
  # one more key
  if [[ ${keys} =~ '^.[ia]$' ]]; then
    zvm_update_cursor
    read -k 1 key
    keys="${keys}${key}"
  elif [[ ${keys} =~ '^.g$' ]]; then
    # If the 2nd character is `g`, we should also read
    # one more key for `gg`
    zvm_update_cursor
    read -k 1 key
    keys="${keys}${key}"
  fi

  # Exit operator pending mode
  zvm_exit_oppend_mode

  # Handle escape in operator pending mode
  # escape non-printed characters (e.g. ^[)
  if [[ $(zvm_escape_non_printed_characters "$keys") =~
    ${ZVM_VI_OPPEND_ESCAPE_BINDKEY/\^\[/\\^\\[} ]]; then
    return $ZVM_RANGE_HANDLER_RET_CANCEL
  fi

  # Enter visual mode or visual line mode
  if [[ $ZVM_MODE != $ZVM_MODE_VISUAL &&
    $ZVM_MODE != $ZVM_MODE_VISUAL_LINE ]]; then
    case "${keys}" in
      [cdy][jk]) mode=$ZVM_MODE_VISUAL_LINE;;
      cc|dd|yy) mode=$ZVM_MODE_VISUAL_LINE;;
      *) mode=$ZVM_MODE_VISUAL;;
    esac
    # Select the mode
    if [[ ! -z $mode ]]; then
      zvm_select_vi_mode $mode false
    fi
  fi

  # Pre navigation handling
  local navkey=

  if [[ $keys =~ '^c([1-9][0-9]*)?[ia][wW]$' ]]; then
    count=${match[1]:-1}
    navkey=${keys: -2}
  elif [[ $keys =~ '^[cdy]([1-9][0-9]*)?[ia][eE]$' ]]; then
    navkey=
  elif [[ $keys =~ '^c([1-9][0-9]*)?[eEwW]$' ]]; then
    count=${match[1]:-1}
    navkey=c${keys: -1}
  elif [[ $keys =~ '^[cdy]([1-9][0-9]*)?[bB]$' ]]; then
    MARK=$((MARK-1))
    count=${match[1]:-1}
    navkey=${keys: -1}
  elif [[ $keys =~ '^[cdy]([1-9][0-9]*)?([FT].?)$' ]]; then
    MARK=$((MARK-1))
    count=${match[1]:-1}
    navkey=${match[2]}
  elif [[ $keys =~ '^[cdy]([1-9][0-9]*)?j$' ]]; then
    # Exit if there is no line below
    count=${match[1]:-1}
    local i=
    for ((i=$((CURSOR+1)); i<=$#BUFFER; i++)); do
      [[ ${BUFFER[$i]} == $'\n' ]] && navkey='j'
    done
  elif [[ $keys =~ '^[cdy]([1-9][0-9]*)?k$' ]]; then
    # Exit if there is no line above
    count=${match[1]:-1}
    local i=
    for ((i=$((CURSOR+1)); i>0; i--)); do
      [[ ${BUFFER[$i]} == $'\n' ]] && navkey='k'
    done
  elif [[ $keys =~ '^[cdy]([1-9][0-9]*)?[\^h0]$' ]]; then
    MARK=$((MARK-1))
    count=${match[1]:-1}
    navkey=${keys: -1}

    # Exit if the cursor is at the beginning of a line
    if ((MARK < 0)); then
      navkey=
    elif [[ ${BUFFER[$MARK+1]} == $'\n' ]]; then
      navkey=
    fi
  elif [[ $keys =~ '^[cdy]([1-9][0-9]*)?l$' ]]; then
    count=${match[1]:-1}
    count=$((count-1))
    navkey=${count}l
  elif [[ $keys =~ '^[cdy]([1-9][0-9]*)?G$' ]]; then
    count=${match[1]:-1}
    navkey=G
  elif [[ $keys =~ '^[cdy]([1-9][0-9]*)?gg$' ]]; then
    MARK=$((MARK-1))
    count=${match[1]:-1}
    navkey=gg
  elif [[ $keys =~ '^.([1-9][0-9]*)?([^0-9]+)$' ]]; then
    count=${match[1]:-1}
    navkey=${match[2]}
  else
    navkey=
  fi

  # Handle navigation
  case $navkey in
    '') exit_code=$ZVM_RANGE_HANDLER_RET_CONTINUE;;
    *[ia]?)
      # At least 1 time
      if [[ -z $count ]]; then
        count=1
      fi

      # Retrieve the widget
      cmd=
      case ${navkey: -2} in
        iw) cmd=(zle select-in-word);;
        aw) cmd=(zle select-a-word);;
        iW) cmd=(zle select-in-blank-word);;
        aW) cmd=(zle select-a-blank-word);;
      esac

      if [[ -n "$cmd" ]]; then
        zvm_repeat_command "$cmd" $count
      elif [[ -n "$(zvm_match_surround "${keys[-1]}")" ]]; then
        ZVM_KEYS="${keys}"
        exit_code=$ZVM_RANGE_HANDLER_RET_PUSHBACK
      elif [[ "${keys[1]}" == 'v' ]]; then
        exit_code=$ZVM_RANGE_HANDLER_RET_CONTINUE
      else
        exit_code=$ZVM_RANGE_HANDLER_RET_CANCEL
      fi
      ;;
    c[eEwW])
      if [[ "${BUFFER[$((CURSOR + 1))]}" == ' ' ]]; then
        case ${navkey: -1} in
          w) cmd=(zle vi-forward-word);;
          W) cmd=(zle vi-forward-blank-word);;
          e) cmd=(zle vi-forward-word-end);;
          E) cmd=(zle vi-forward-blank-word-end);;
        esac

        zvm_repeat_command "$cmd" $count

        case ${navkey: -1} in
          w|W) CURSOR=$((CURSOR-1));;
        esac
      else
        if [[ "${BUFFER[$((CURSOR + 2))]}" == ' ' ]]; then
          count=$((count - 1))
        fi

        case ${navkey: -1} in
          e|w) cmd=(zle vi-forward-word-end);;
          E|W) cmd=(zle vi-forward-blank-word-end);;
        esac

        zvm_repeat_command "$cmd" $count
      fi
      ;;
    *)
      local retval=

      # Prevent some actions(e.g. w, e) from affecting the auto
      # suggestion suffix
      BUFFER+=$'\0'

      if zvm_navigation_handler "${count}${navkey}"; then
        keys="${keys[1]}${retval}"
      else
        exit_code=$ZVM_RANGE_HANDLER_RET_CONTINUE
      fi

      BUFFER[-1]=''
      ;;
  esac

  # Check if there is no range selected
  if [[ $exit_code != 0 ]]; then
    return $exit_code
  fi

  # Post navigation handling
  if [[ $keys =~ '^[cdy]([1-9][0-9]*)?[ia][wW]$' ]]; then
    cursor=$MARK
  elif [[ $keys =~ '[dy]([1-9][0-9]*)?[wW]' ]]; then
    CURSOR=$((CURSOR-1))
    # If the CURSOR is at the newline character, we should
    # move backward a character
    if [[ "${BUFFER:$CURSOR:1}" == $'\n' ]]; then
      CURSOR=$((CURSOR-1))
    fi
  else
    cursor=$CURSOR
  fi

  # Handle operation
  case "${keys}" in
    c*) zvm_vi_change false; cursor=;;
    d*) zvm_vi_delete false; cursor=;;
    y*) zvm_vi_yank false; cursor=;;
    [vV]*) cursor=;;
  esac

  # Restore cursor position
  if [[ -n $cursor ]]; then
    CURSOR=$cursor
  fi

  return $exit_code
}

# Find and move cursor to next character
# Used for f/F/t/T commands to find characters in the line
function zvm_find_and_move_cursor() {
  local char=$1
  local count=${2:-1}
  local forward=${3:-true}
  local skip=${4:-false}
  local cursor=$CURSOR

  [[ -z $char ]] && return 1

  # Find the specific character
  while :; do
    if $forward; then
      cursor=$((cursor+1))
      ((cursor > $#BUFFER)) && break
    else
      cursor=$((cursor-1))
      ((cursor < 0)) && break
    fi
    if [[ ${BUFFER[$cursor+1]} == $char ]]; then
      count=$((count-1))
    fi
    ((count == 0)) && break
  done

  [[ $count > 0 ]] && return 1

  # Skip the character
  if $skip; then
    if $forward; then
      cursor=$((cursor-1))
    else
      cursor=$((cursor+1))
    fi
  fi

  CURSOR=$cursor
}
