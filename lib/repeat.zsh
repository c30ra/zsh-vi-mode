# repeat.zsh - Repeat command functionality
# Implements the dot (.) command and related repeat operations

# Repeat last change (. command)
function zvm_repeat_change() {
  local times=${NUMERIC:-1}
  ZVM_REPEAT_MODE=true
  ZVM_RESET_PROMPT_DISABLED=true

  local cmd=${ZVM_REPEAT_COMMANDS[2]}

  # Handle repeat command for the specified number of times
  local i=
  for ((i=0; i<$times; i++)); do
    case $cmd in
      [aioAIO]) zvm_repeat_insert;;
      c) zvm_repeat_vi_change;;
      [cd]*) zvm_repeat_range_change;;
      R) zvm_repeat_replace;;
      r) zvm_repeat_replace_chars;;
      *) zle vi-repeat-change;;
    esac
  done

  zle redisplay

  ZVM_RESET_PROMPT_DISABLED=false
  ZVM_REPEAT_MODE=false
}

# Repeat inserting characters
function zvm_repeat_insert() {
  local cmd=${ZVM_REPEAT_COMMANDS[2]}
  local cmds=(${ZVM_REPEAT_COMMANDS[3,-1]})

  # Pre-handle the command
  case $cmd in
    a) CURSOR+=1;;
    o)
      zle vi-backward-char
      zle vi-end-of-line
      LBUFFER+=$'\n'
      ;;
    A)
      zle vi-end-of-line
      CURSOR=$((CURSOR+1))
      ;;
    I) zle vi-first-non-blank;;
    O)
      zle vi-digit-or-beginning-of-line
      LBUFFER+=$'\n'
      CURSOR=$((CURSOR-1))
      ;;
  esac

  # Insert characters
  local i=
  for ((i=1; i<=${#cmds[@]}; i++)); do
    cmd="${cmds[$i]}"

    # Handle the backspace command
    if [[ $cmd == '' ]]; then
      if (($#LBUFFER > 0)); then
        LBUFFER=${LBUFFER:0:-1}
      fi
      continue
    fi

    # The length of character should be 1
    if (($#cmd == 1)); then
      zvm_self_insert "$cmd"
    fi
  done
}

# Repeat changing visual characters
function zvm_repeat_vi_change() {
  local mode=${ZVM_REPEAT_COMMANDS[1]}
  local cmds=(${ZVM_REPEAT_COMMANDS[3,-1]})

  # Backward move cursor to the beginning of line
  if [[ $mode == $ZVM_MODE_VISUAL_LINE ]]; then
    zle vi-digit-or-beginning-of-line
  fi

  local ncount=${cmds[1]}
  local ccount=${cmds[2]}
  local pos=$CURSOR epos=$CURSOR
  local i=

  # Forward expand the characters to the Nth newline character
  for ((i=0; i<$ncount; i++)); do
    pos=$(zvm_substr_pos $BUFFER $'\n' $pos)
    if [[ $pos == -1 ]]; then
      epos=$#BUFFER
      break
    fi
    pos=$((pos+1))
    epos=$pos
  done

  # Forward expand the remaining characters
  for ((i=0; i<$ccount; i++)); do
    local char=${BUFFER[$epos+i]}
    if [[ $char == $'\n' || $char == '' ]]; then
      ccount=$i
      break
    fi
  done

  epos=$((epos+ccount))
  RBUFFER=${RBUFFER:$((epos-CURSOR))}
}

# Repeat changing a range of characters
function zvm_repeat_range_change() {
  local cmd=${ZVM_REPEAT_COMMANDS[2]}

  # Remove characters
  zvm_range_handler $cmd

  # Insert characters
  zvm_repeat_insert
}

# Repeat replacing (R command)
function zvm_repeat_replace() {
  local cmds=(${ZVM_REPEAT_COMMANDS[3,-1]})
  local cmd=
  local cursor=$CURSOR
  local i=

  for ((i=1; i<=${#cmds[@]}; i++)); do
    cmd="${cmds[$i]}"

    # If the cmd or the character at cursor is a newline character,
    # or the cursor is at the end of buffer, we should insert the
    # cmd instead of replacing with the cmd.
    if [[ $cmd == $'\n' ||
      $BUFFER[$cursor+1] == $'\n' ||
      $BUFFER[$cursor+1] == ''
    ]]; then
      LBUFFER+=$cmd
    else
      BUFFER[$cursor+1]=$cmd
    fi

    cursor=$((cursor+1))
    CURSOR=$cursor
  done

  # The cursor position should go back one character after
  # exiting the replace mode
  zle vi-backward-char
}

# Repeat replacing characters (r command)
function zvm_repeat_replace_chars() {
  local mode=${ZVM_REPEAT_COMMANDS[1]}
  local cmds=(${ZVM_REPEAT_COMMANDS[3,-1]})
  local cmd=

  # Replacment of visual mode should move backward cursor to the
  # begin of current line, and replacing to the end of last line.
  if [[ $mode == $ZVM_MODE_VISUAL_LINE ]]; then
    zle vi-digit-or-beginning-of-line
    cmds+=($'\n')
  fi

  local cursor=$((CURSOR+1))
  local i=

  for ((i=1; i<=${#cmds[@]}; i++)); do
    cmd="${cmds[$i]}"

    # If we meet a newline character in the buffer, we should keep
    # stop replacing, util we meet next newline character command.
    if [[ ${BUFFER[$cursor]} == $'\n' ]]; then
      if [[ $cmd == $'\n' ]]; then
        cursor=$((cursor+1))
      fi
      continue
    fi

    # A newline character command should keep replacing with last
    # character, until we meet a newline character in the buffer,
    # then we use next command.
    if [[ $cmd == $'\n' ]]; then
      i=$((i-1))
      cmd="${cmds[$i]}"
    fi

    # The length of character should be 1
    if (($#cmd == 1)); then
      BUFFER[$cursor]="${cmd}"
    fi

    cursor=$((cursor+1))

    # Break when it reaches the end
    if ((cursor > $#BUFFER)); then
      break
    fi
  done
}

# Updates repeat commands
function zvm_update_repeat_commands() {
  # We don't need to update the repeat commands if current
  # mode is already the repeat mode.
  $ZVM_REPEAT_MODE && return

  # We don't need to update the repeat commands if it is
  # reseting the repeat commands.
  if $ZVM_REPEAT_RESET; then
    ZVM_REPEAT_RESET=false
    return
  fi

  # We update the repeat commands when it's the insert mode
  [[ $ZVM_MODE == $ZVM_MODE_INSERT ]] || return

  local char=$KEYS

  # If current key is an arrow key, we should do something
  if [[ "$KEYS" =~ '\\e\[[ABCD]' ]]; then
    # If last key is also an arrow key, we just replace it
    if [[ ${ZVM_REPEAT_COMMANDS[-1]} =~ '\\e\[[ABCD]' ]]; then
      ZVM_REPEAT_COMMANDS=(${ZVM_REPEAT_COMMANDS[@]:0:-1})
    fi
  else
    # If last command is arrow key movement, we should reset
    # the repeat commands with i(nsert) command
    if [[ ${ZVM_REPEAT_COMMANDS[-1]} =~ '\\e\[[ABCD]' ]]; then
      zvm_reset_repeat_commands $ZVM_MODE_NORMAL i
    fi
    char=${BUFFER[$CURSOR]}
  fi

  # If current key is backspace key, we should remove last
  # one, until it has only the mode and inital command
  if [[ "$KEYS" == '\x7f' || "$KEYS" == '127' || "$KEYS" == '\177' ]]; then
    if ((${#ZVM_REPEAT_COMMANDS[@]} > 2)) &&
      [[ ${ZVM_REPEAT_COMMANDS[-1]} != '\x7f' ]]; then
      ZVM_REPEAT_COMMANDS=(${ZVM_REPEAT_COMMANDS[@]:0:-1})
    elif (($#LBUFFER > 0)); then
      ZVM_REPEAT_COMMANDS+=($KEYS)
    fi
  else
    ZVM_REPEAT_COMMANDS+=($char)
  fi
}
