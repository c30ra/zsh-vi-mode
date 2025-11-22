# url.zsh - URL and file path handling
# Detect and open URLs or file paths under cursor

# Edit command line in external editor
# Opens current command in configured editor for editing (v command)
function zvm_vi_edit_command_line() {
  # Create a temporary file and save the BUFFER to it
  local tmp_file=$(mktemp ${ZVM_TMPDIR}/zshXXXXXX)

  # Some users may config the noclobber option to prevent from
  # overwriting existing files with the > operator, we should
  # use >! operator to ignore the noclobber.
  echo "$BUFFER" >! "$tmp_file"

  # Edit the file with the specific editor, in case of
  # the warning about input not from a terminal (e.g.
  # vim), we should tell the editor input is from the
  # terminal and not from standard input.
  "${(@Q)${(z)${ZVM_VI_EDITOR}}}" $tmp_file </dev/tty

  # Reload the content to the BUFFER from the temporary
  # file after editing, and delete the temporary file.
  BUFFER=$(cat "$tmp_file")
  rm "$tmp_file"

  # Exit the visual mode
  case $ZVM_MODE in
    $ZVM_MODE_VISUAL|$ZVM_MODE_VISUAL_LINE)
      zvm_exit_visual_mode
      ;;
  esac
}

# Check if content is valid URL
# Validates if text matches URL pattern
function zvm_is_url() {
  local content="$1"

  # Check if it starts with a valid scheme
  if [[ "$content" =~ $ZVM_URL_REGEX ]]; then
    return 0
  fi

  return 1
}

# Check if content is a valid file path
# Validates if text is an existing file or directory
function zvm_is_path() {
  local content="$1"

  # Expand ~ if present
  if [[ "$content" =~ '^~' ]]; then
    content="${HOME}${content:1}"
  fi

  # Check if path exists
  if [[ -e "$content" ]]; then
    return 0
  fi

  return 1
}

# Select a URL or path under the cursor
# Finds and returns position of URL or path near cursor
function zvm_select_url_or_path() {
  local cursor=${1:-$CURSOR}
  local buffer=${2:-$BUFFER}
  local bpos= epos=
  local _bpos=0 _epos=$#buffer
  local content=

  # Find the beginning the current line
  for ((bpos=$cursor; $bpos>=0; bpos--)); do
    if [[ "${buffer:$bpos:1}" == $'\n' ]]; then
      _bpos=$((bpos+1))
      break
    fi
  done

  # Find the end of current line
  for ((epos=$cursor; $epos<$#buffer; epos++)); do
    if [[ "${buffer:$epos:1}" == $'\n' ]]; then
      _epos=$epos
      break
    fi
  done

  # Search for the URL or path
  for ((bpos=$_bpos; $bpos<=$cursor; bpos++)); do
    for ((epos=$((_epos-1)); $epos>=$cursor; epos--)); do
      content=${buffer:$bpos:$((epos-bpos+1))}
      if zvm_is_url "$content" || zvm_is_path "$content"; then
        echo $bpos $epos
        return
      fi
    done
  done

  echo $cursor $cursor
}

# Open URL or file under cursor
# Detects and opens URL or file path under cursor (gx command)
function zvm_open_under_cursor() {
  # Get the word under the cursor
  local ret=($(zvm_select_url_or_path $CURSOR $BUFFER))
  local bpos=${ret[1]} epos=${ret[2]}
  local content=${BUFFER:$bpos:$((epos-bpos+1))}

  # Check if it's a valid URL
  if zvm_is_url "$content"; then
    # Open URL with default browser
    if [[ -n $ZVM_OPEN_URL_CMD ]]; then
      local -a cmd
      cmd=("${(z)ZVM_OPEN_URL_CMD}")
      "$cmd[@]" "$content"
    elif zvm_exist_command "open"; then
      open "$content"
    elif zvm_exist_command "xdg-open"; then
      xdg-open "$content"
    fi
  # Check if it's a valid path
  elif zvm_is_path "$content"; then
    if [[ -n $ZVM_OPEN_FILE_CMD ]]; then
      local -a cmd
      cmd=("${(z)ZVM_OPEN_FILE_CMD}")
      "$cmd[@]" "$content"
    elif zvm_exist_command "open"; then
      open "$content"
    elif zvm_exist_command "xdg-open"; then
      xdg-open "$content"
    fi
  fi
}

# Get the substr position in a string
# Helper function to find substring position with direction support
function zvm_substr_pos() {
  local pos=-1
  local len=${#1}
  local slen=${#2}
  local i=${3:-0}
  local forward=${4:-true}
  local init=${i:-$($forward && echo "$i" || echo "i=$len-1")}
  local condition=$($forward && echo "i<$len" || echo "i>=0")
  local step=$($forward && echo 'i++' || echo 'i--')
  for (($init;$condition;$step)); do
    if [[ ${1:$i:$slen} == "$2" ]]; then
      pos=$i
      break
    fi
  done
  echo $pos
}
