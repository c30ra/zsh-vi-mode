# editor.zsh - Text editing operations
# Core VI editing functions: delete, yank, change, put/paste, case transformation

# Get the beginning and end position of selection
function zvm_selection() {
  local bpos= epos=
  if (( MARK > CURSOR )) ; then
    bpos=$CURSOR epos=$((MARK+1))
  else
    bpos=$MARK epos=$((CURSOR+1))
  fi
  echo $bpos $epos
}

# Calculate the region of selection
function zvm_calc_selection() {
  local ret=($(zvm_selection))
  local bpos=${ret[1]} epos=${ret[2]} cpos=

  # Save the current cursor position
  cpos=$bpos

  # Check if it is visual-line mode
  if [[ "${1:-$ZVM_MODE}" == $ZVM_MODE_VISUAL_LINE ]]; then

    # Extend the selection to whole line
    for ((bpos=$bpos-1; $bpos>0; bpos--)); do
      if [[ "${BUFFER:$bpos:1}" == $'\n' ]]; then
        bpos=$((bpos+1))
        break
      fi
    done
    for ((epos=$epos-1; $epos<$#BUFFER; epos++)); do
      if [[ "${BUFFER:$epos:1}" == $'\n' ]]; then
        break
      fi
    done

    # The begin position must not be less than zero
    if (( bpos < 0 )); then
      bpos=0
    fi

    ###########################################
    # Calculate the new cursor position, here we consider that
    # the selection will be delected.

    # Calculate the indent of current cursor line
    for ((cpos=$((CURSOR-1)); $cpos>=0; cpos--)); do
      [[ "${BUFFER:$cpos:1}" == $'\n' ]] && break
    done

    local indent=$((CURSOR-cpos-1))

    # If the selection includes the last line, the cursor
    # will move up to above line. Otherwise the cursor will
    # keep in the same line.

    local hpos= # Line head position
    local rpos= # Reference position

    if (( $epos < $#BUFFER )); then
      # Get the head position of next line
      hpos=$((epos+1))
      rpos=$bpos
    else
      # Get the head position of above line
      for ((hpos=$((bpos-2)); $hpos>0; hpos--)); do
        if [[ "${BUFFER:$hpos:1}" == $'\n' ]]; then
          break
        fi
      done
      if (( $hpos < -1 )); then
        hpos=-1
      fi
      hpos=$((hpos+1))
      rpos=$hpos
    fi

    # Calculate the cursor postion, the indent must be
    # less than the line characters.
    for ((cpos=$hpos; $cpos<$#BUFFER; cpos++)); do
      if [[ "${BUFFER:$cpos:1}" == $'\n' ]]; then
        break
      fi
      if (( $hpos + $indent <= $cpos )); then
        break
      fi
    done

    cpos=$((rpos+cpos-hpos))
  fi

  echo $bpos $epos $cpos
}

# Backward remove characters of an emacs region in the line
function zvm_backward_kill_region() {
  local bpos=$CURSOR-1 epos=$CURSOR

  # Backward search the boundary of current region
  for ((; bpos >= 0; bpos--)); do
    # Break when cursor is at the beginning of line
    [[ "${BUFFER:$bpos:1}" == $'\n' ]] && break

    # Break when cursor is at the boundary of a word region
    [[ "${BUFFER:$bpos:2}" =~ ^\ [^\ $'\n']$ ]] && break
  done

  bpos=$bpos+1
  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}
  BUFFER="${BUFFER:0:$bpos}${BUFFER:$epos}"
  CURSOR=$bpos
  zvm_clipboard_copy_buffer
}

# Remove all characters between the cursor position and the beginning of the line
function zvm_backward_kill_line() {
  BUFFER=${BUFFER:$CURSOR:$#BUFFER}
  CURSOR=0
}

# Remove all characters between the cursor position and the end of the line
function zvm_forward_kill_line() {
  BUFFER=${BUFFER:0:$CURSOR}
}

# Remove all characters of the line
function zvm_kill_line() {
  local ret=($(zvm_calc_selection $ZVM_MODE_VISUAL_LINE))
  local bpos=${ret[1]} epos=${ret[2]}
  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}$'\n'
  BUFFER="${BUFFER:0:$bpos}${BUFFER:$epos}"
  CURSOR=$bpos
  zvm_clipboard_copy_buffer
}

# Remove all characters of the whole line
function zvm_kill_whole_line() {
  local ret=($(zvm_calc_selection $ZVM_MODE_VISUAL_LINE))
  local bpos=$ret[1] epos=$ret[2] cpos=$ret[3]
  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}$'\n'

  # Adjust region range of deletion
  if (( $epos < $#BUFFER )); then
    epos=$epos+1
  fi

  BUFFER="${BUFFER:0:$bpos}${BUFFER:$epos}"
  CURSOR=$cpos
  zvm_clipboard_copy_buffer
}

# Exchange the point and mark (visual mode toggle anchor)
function zvm_exchange_point_and_mark() {
  cursor=$MARK
  MARK=$CURSOR CURSOR=$cursor
  zvm_highlight
}

# Open line below (o command)
function zvm_open_line_below() {
  local i=$CURSOR

  # If there is a completion suffix, we should break at the
  # postion of suffix begin, otherwise, it should break when
  # forward finding out the first newline character.
  for ((; i<$#BUFFER; i++)); do
    if ((SUFFIX_ACTIVE == 1)) && ((i >= SUFFIX_BEGIN)); then
      break
    fi
    if [[ "${BUFFER[$i]}" == $'\n' ]]; then
      i=$((i-1))
      break
    fi
  done

  CURSOR=$i
  LBUFFER+=$'\n'

  zvm_reset_repeat_commands $ZVM_MODE_NORMAL o
  zvm_select_vi_mode $ZVM_MODE_INSERT
}

# Open line above (O command)
function zvm_open_line_above() {
  local i=$CURSOR

  # Break when backward finding out the first newline character.
  for ((; i>0; i--)); do
    if [[ "${BUFFER[$i]}" == $'\n' ]]; then
      break
    fi
  done

  CURSOR=$i
  LBUFFER+=$'\n'
  CURSOR=$((CURSOR-1))

  zvm_reset_repeat_commands $ZVM_MODE_NORMAL O
  zvm_select_vi_mode $ZVM_MODE_INSERT
}

# Replace characters one by one (Replacing mode - R command)
function zvm_vi_replace() {
  if [[ $ZVM_MODE == $ZVM_MODE_NORMAL ]]; then
    local cursor=$CURSOR
    local cache=()
    local cmds=()
    local key=

    zvm_select_vi_mode $ZVM_MODE_REPLACE

    while :; do
      # Read a character for replacing
      zvm_update_cursor

      # Redisplay the command line, this is to be called from within
      # a user-defined widget to allow changes to become visible
      zle -R

      read -k 1 key

      # Escape key will break the replacing process, and enter key
      # will repace with a newline character.
      case $(zvm_escape_non_printed_characters $key) in
        '^['|$ZVM_VI_OPPEND_ESCAPE_BINDKEY) break;;
        '^M') key=$'\n';;
      esac

      # If the key is backspace, we should move backward the cursor
      if [[ $key == '' ]]; then
        # Cursor position should not be less than zero
        if ((cursor > 0)); then
          cursor=$((cursor-1))
        fi

        # We should recover the character when cache size is not zero
        if ((${#cache[@]} > 0)); then
          key=${cache[-1]}

          if [[ $key == '<I>' ]]; then
            key=
          fi

          cache=(${cache[@]:0:-1})
          BUFFER[$cursor+1]=$key

          # Remove from commands
          cmds=(${cmds[@]:0:-1})
        fi
      else
        # If the key or the character at cursor is a newline character,
        # or the cursor is at the end of buffer, we should insert the
        # key instead of replacing with the key.
        if [[ $key == $'\n' ||
          $BUFFER[$cursor+1] == $'\n' ||
          $BUFFER[$cursor+1] == ''
        ]]; then
          cache+=('<I>')
          LBUFFER+=$key
        else
          cache+=(${BUFFER[$cursor+1]})
          BUFFER[$cursor+1]=$key
        fi

        cursor=$((cursor+1))

        # Push to commands
        cmds+=($key)
      fi

      # Update next cursor position
      CURSOR=$cursor

      zle redisplay
    done

    # The cursor position should go back one character after
    # exiting the replace mode
    zle vi-backward-char

    zvm_select_vi_mode $ZVM_MODE_NORMAL
    zvm_reset_repeat_commands $ZVM_MODE R $cmds
  elif [[ $ZVM_MODE == $ZVM_MODE_VISUAL ]]; then
    zvm_enter_visual_mode V
    zvm_vi_change
  elif [[ $ZVM_MODE == $ZVM_MODE_VISUAL_LINE ]]; then
    zvm_vi_change
  fi
}

# Replace characters in one time (r command)
function zvm_vi_replace_chars() {
  local cmds=()
  local key=

  # Read a character for replacing
  zvm_enter_oppend_mode

  # Redisplay the command line, this is to be called from within
  # a user-defined widget to allow changes to become visible
  zle redisplay
  zle -R

  read -k 1 key

  zvm_exit_oppend_mode

  # Escape key will break the replacing process
  case $(zvm_escape_non_printed_characters $key) in
    $ZVM_VI_OPPEND_ESCAPE_BINDKEY)
      zvm_exit_visual_mode
      return
  esac

  if [[ $ZVM_MODE == $ZVM_MODE_NORMAL ]]; then
    cmds+=($key)
    BUFFER[$CURSOR+1]=$key
  else
    local ret=($(zvm_calc_selection))
    local bpos=${ret[1]} epos=${ret[2]}
    for ((bpos=bpos+1; bpos<=epos; bpos++)); do
      # Newline character is no need to be replaced
      if [[ $BUFFER[$bpos] == $'\n' ]]; then
        cmds+=($'\n')
        continue
      fi

      cmds+=($key)
      BUFFER[$bpos]=$key
    done
    zvm_exit_visual_mode
  fi

  # Reset the repeat commands
  zvm_reset_repeat_commands $ZVM_MODE r $cmds
}

# Substitute characters of selection (s command)
function zvm_vi_substitute() {
  # Substitute one character in normal mode
  if [[ $ZVM_MODE == $ZVM_MODE_NORMAL ]]; then
    BUFFER="${BUFFER:0:$CURSOR}${BUFFER:$((CURSOR+1))}"
    zvm_reset_repeat_commands $ZVM_MODE c 0 1
    zvm_select_vi_mode $ZVM_MODE_INSERT
  else
    zvm_vi_change
  fi
}

# Substitute all characters of a line (S command)
function zvm_vi_substitute_whole_line() {
  zvm_select_vi_mode $ZVM_MODE_VISUAL_LINE false
  zvm_vi_substitute
}

# Yank characters of the marked region
function zvm_yank() {
  local ret=($(zvm_calc_selection $1))
  local bpos=$ret[1] epos=$ret[2] cpos=$ret[3]
  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}
  if [[ ${1:-$ZVM_MODE} == $ZVM_MODE_VISUAL_LINE ]]; then
    CUTBUFFER=${CUTBUFFER}$'\n'
  fi
  CURSOR=$bpos MARK=$epos
  zvm_clipboard_copy_buffer
}

# Yank characters of the visual selection (y command)
function zvm_vi_yank() {
  zvm_yank
  zvm_exit_visual_mode ${1:-true}
}

# Delete characters of the visual selection (d command)
function zvm_vi_delete() {
  zvm_replace_selection
  zvm_exit_visual_mode ${1:-true}
}

# Change characters of the visual selection (c command)
function zvm_vi_change() {
  local ret=($(zvm_calc_selection))
  local bpos=$ret[1] epos=$ret[2]

  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}

  # Check if it is visual line mode
  if [[ $ZVM_MODE == $ZVM_MODE_VISUAL_LINE ]]; then
    CUTBUFFER=${CUTBUFFER}$'\n'
  fi

  BUFFER="${BUFFER:0:$bpos}${BUFFER:$epos}"
  CURSOR=$bpos
  zvm_clipboard_copy_buffer

  # Return when it's repeating mode
  $ZVM_REPEAT_MODE && return

  # Reset the repeat commands
  if [[ $ZVM_MODE != $ZVM_MODE_NORMAL ]]; then
    local npos=0 ncount=0 ccount=0
    # Count the amount of newline character and the amount of
    # characters after the last newline character.
    while :; do
      # Forward find the last newline character's position
      npos=$(zvm_substr_pos $CUTBUFFER $'\n' $npos)
      if [[ $npos == -1 ]]; then
        if (($ncount == 0)); then
          ccount=$#CUTBUFFER
        fi
        break
      fi
      npos=$((npos+1))
      ncount=$(($ncount + 1))
      ccount=$(($#CUTBUFFER - $npos))
    done
    zvm_reset_repeat_commands $ZVM_MODE c $ncount $ccount
  fi

  zvm_exit_visual_mode false
  zvm_select_vi_mode $ZVM_MODE_INSERT ${1:-true}
}

# Change characters from cursor to the end of current line (C command)
function zvm_vi_change_eol() {
  local bpos=$CURSOR epos=$CURSOR

  # Find the end of current line
  for ((; $epos<$#BUFFER; epos++)); do
    if [[ "${BUFFER:$epos:1}" == $'\n' ]]; then
      break
    fi
  done

  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}
  BUFFER="${BUFFER:0:$bpos}${BUFFER:$epos}"

  zvm_clipboard_copy_buffer
  zvm_reset_repeat_commands $ZVM_MODE c 0 $#CUTBUFFER
  zvm_select_vi_mode $ZVM_MODE_INSERT
}

# Put cutbuffer after the cursor (p command)
function zvm_vi_put_after() {
  local count=${NUMERIC:-1}
  local head= foot=
  local content=${CUTBUFFER}
  local offset=1

  if [[ ${content: -1} == $'\n' ]]; then
    local pos=${CURSOR}

    # Find the end of current line
    for ((; $pos<$#BUFFER; pos++)); do
      if [[ ${BUFFER:$pos:1} == $'\n' ]]; then
        pos=$pos+1
        break
      fi
    done

    head=${BUFFER:0:$pos}
    foot=${BUFFER:$pos}

    # If at end of buffer (no trailing newline), prepend one and drop trailing one
    if ! zvm_is_empty_line; then
      if [[ $pos == $#BUFFER ]]; then
        content=$'\n'${content:0:-1}
        pos=$pos+1
        head=${BUFFER:0:$pos}
        foot=${BUFFER:$pos}
      fi
    fi

    local repeated= i=
    for ((i=1; i<=count; i++)); do
      repeated+="$content"
    done

    offset=0
    BUFFER="${head}${repeated}${foot}"
    CURSOR=$pos
  else
    local char_at_cursor=${BUFFER:$CURSOR:1}

    # Special handling if cursor at an empty line
    if zvm_is_empty_line; then
      head="${BUFFER:0:$((CURSOR-1))}"
      foot="${BUFFER:$CURSOR}"
    else
      head="${BUFFER:0:$CURSOR}"
      foot="${BUFFER:$((CURSOR+1))}"
    fi

    local repeated= i=
    for ((i=1; i<=count; i++)); do
      repeated+="$content"
    done

    BUFFER="${head}${char_at_cursor}${repeated}${foot}"
    CURSOR=$CURSOR+$#repeated
  fi

  # Reresh display and highlight buffer
  zvm_highlight clear
  zvm_highlight custom $(($#head+$offset)) $(($#head+$#repeated+$offset))
}

# Put cutbuffer before the cursor (P command)
function zvm_vi_put_before() {
  local count=${NUMERIC:-1}
  local head= foot=
  local content=${CUTBUFFER}

  if [[ ${content: -1} == $'\n' ]]; then
    local pos=$CURSOR

    # Find the beginning of current line
    for ((; $pos>0; pos--)); do
      if [[ "${BUFFER:$pos:1}" == $'\n' ]]; then
        pos=$pos+1
        break
      fi
    done

    # Check if it is an empty line
    if zvm_is_empty_line; then
      head=${BUFFER:0:$((pos-1))}
      foot=$'\n'${BUFFER:$pos}
      pos=$((pos-1))
    else
      head=${BUFFER:0:$pos}
      foot=${BUFFER:$pos}
    fi

    local repeated= i=
    for ((i=1; i<=count; i++)); do
      repeated+="$content"
    done

    BUFFER="${head}${repeated}${foot}"
    CURSOR=$pos
  else
    head="${BUFFER:0:$CURSOR}"
    foot="${BUFFER:$((CURSOR+1))}"

    local repeated= i=
    for ((i=1; i<=count; i++)); do
      repeated+="$content"
    done

    BUFFER="${head}${repeated}${BUFFER:$CURSOR:1}${foot}"
    CURSOR=$CURSOR+$#repeated
    CURSOR=$((CURSOR-1))
  fi

  # Reresh display and highlight buffer
  zvm_highlight clear
  zvm_highlight custom $#head $(($#head+$#repeated))
}

# Replace a selection
function zvm_replace_selection() {
  local ret=($(zvm_calc_selection))
  local bpos=$ret[1] epos=$ret[2] cpos=$ret[3]
  local cutbuf=$1

  # If there's a replacement, we need to calculate cursor position
  if (( $#cutbuf > 0 )); then
    cpos=$(($bpos + $#cutbuf - 1))
  fi

  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}

  # Check if it is visual line mode
  if [[ $ZVM_MODE == $ZVM_MODE_VISUAL_LINE ]]; then
    if (( $epos < $#BUFFER )); then
      epos=$epos+1
    elif (( $bpos > 0 )); then
      bpos=$bpos-1
    fi
    CUTBUFFER=${CUTBUFFER}$'\n'
  fi

  BUFFER="${BUFFER:0:$bpos}${cutbuf}${BUFFER:$epos}"
  CURSOR=$cpos
  zvm_clipboard_copy_buffer
}

# Replace characters of the visual selection
function zvm_vi_replace_selection() {
  zvm_replace_selection $CUTBUFFER
  zvm_exit_visual_mode ${1:-true}
}

# Up case of the visual selection (U command)
function zvm_vi_up_case() {
  local ret=($(zvm_selection))
  local bpos=${ret[1]} epos=${ret[2]}
  local content=${BUFFER:$bpos:$((epos-bpos))}
  BUFFER="${BUFFER:0:$bpos}${(U)content}${BUFFER:$epos}"
  zvm_exit_visual_mode
}

# Down case of the visual selection (u command)
function zvm_vi_down_case() {
  local ret=($(zvm_selection))
  local bpos=${ret[1]} epos=${ret[2]}
  local content=${BUFFER:$bpos:$((epos-bpos))}
  BUFFER="${BUFFER:0:$bpos}${(L)content}${BUFFER:$epos}"
  zvm_exit_visual_mode
}

# Opposite case of the visual selection (~ command)
function zvm_vi_opp_case() {
  local ret=($(zvm_selection))
  local bpos=${ret[1]} epos=${ret[2]}
  local content=${BUFFER:$bpos:$((epos-bpos))}
  local i=
  for ((i=1; i<=$#content; i++)); do
    if [[ ${content[i]} =~ [A-Z] ]]; then
      content[i]=${(L)content[i]}
    elif [[ ${content[i]} =~ [a-z] ]]; then
      content[i]=${(U)content[i]}
    fi
  done
  BUFFER="${BUFFER:0:$bpos}${content}${BUFFER:$epos}"
  zvm_exit_visual_mode
}

# Yank characters of the marked region
function zvm_yank() {
  local ret=($(zvm_calc_selection $1))
  local bpos=$ret[1] epos=$ret[2] cpos=$ret[3]
  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}
  if [[ ${1:-$ZVM_MODE} == $ZVM_MODE_VISUAL_LINE ]]; then
    CUTBUFFER=${CUTBUFFER}$'\n'
  fi
  CURSOR=$bpos MARK=$epos
  zvm_clipboard_copy_buffer
}

# Yank characters of the visual selection (y command)
function zvm_vi_yank() {
  zvm_yank
  zvm_exit_visual_mode ${1:-true}
}

# Delete characters of the visual selection (d/x command)
function zvm_vi_delete() {
  zvm_replace_selection
  zvm_exit_visual_mode ${1:-true}
}

# Change characters of visual selection and enter insert mode (c command)
function zvm_vi_change() {
  local ret=($(zvm_calc_selection))
  local bpos=$ret[1] epos=$ret[2]

  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}

  # Check if it is visual line mode
  if [[ $ZVM_MODE == $ZVM_MODE_VISUAL_LINE ]]; then
    CUTBUFFER=${CUTBUFFER}$'\n'
  fi

  BUFFER="${BUFFER:0:$bpos}${BUFFER:$epos}"
  CURSOR=$bpos
  zvm_clipboard_copy_buffer

  # Return when it's repeating mode
  $ZVM_REPEAT_MODE && return

  # Reset the repeat commands
  if [[ $ZVM_MODE != $ZVM_MODE_NORMAL ]]; then
    local npos=0 ncount=0 ccount=0
    # Count the amount of newline character and the amount of
    # characters after the last newline character.
    while :; do
      # Forward find the last newline character's position
      npos=$(zvm_substr_pos $CUTBUFFER $'\n' $npos)
      if [[ $npos == -1 ]]; then
        if (($ncount == 0)); then
          ccount=$#CUTBUFFER
        fi
        break
      fi
      npos=$((npos+1))
      ncount=$(($ncount + 1))
      ccount=$(($#CUTBUFFER - $npos))
    done
    zvm_reset_repeat_commands $ZVM_MODE c $ncount $ccount
  fi

  zvm_exit_visual_mode false
  zvm_select_vi_mode $ZVM_MODE_INSERT ${1:-true}
}

# Change characters from cursor to the end of current line (C command)
function zvm_vi_change_eol() {
  local bpos=$CURSOR epos=$CURSOR

  # Find the end of current line
  for ((; $epos<$#BUFFER; epos++)); do
    if [[ "${BUFFER:$epos:1}" == $'\n' ]]; then
      break
    fi
  done

  CUTBUFFER=${BUFFER:$bpos:$((epos-bpos))}
  BUFFER="${BUFFER:0:$bpos}${BUFFER:$epos}"

  zvm_clipboard_copy_buffer
  zvm_reset_repeat_commands $ZVM_MODE c 0 $#CUTBUFFER
  zvm_select_vi_mode $ZVM_MODE_INSERT
}
