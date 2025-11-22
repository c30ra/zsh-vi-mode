# Utility functions for zsh-vi-mode
# Contains helper functions used throughout the plugin

# Display version information
function zvm_version() {
  local git_info=$(git show -s --format="(%h, %ci)" 2>/dev/null)
  echo -e "$ZVM_NAME $ZVM_VERSION $git_info"
  echo -e "\e[4m$ZVM_REPOSITORY\e[0m"
  echo -e "$ZVM_DESCRIPTION"
}

# The widget wrapper
function zvm_widget_wrapper() {
  local rawfunc=$1;
  local func=$2;
  local called=$3;
  local -i retval=0
  if ! $called; then
    $rawfunc "${@:4}"
    retval=$?
  fi
  $func "${@:4}"
  [[ $retval -eq 0 ]] && retval=$?
  return $retval
}

# Define widget function
function zvm_define_widget() {
  local widget=$1
  local func=${2:-$1}

  # If zle isn't available (non-interactive), skip the zle introspection
  local result=()
  if zvm_exist_command zle 2>/dev/null || command -v zle >/dev/null 2>&1; then
    # shellcheck disable=SC2194
    result=($(zle -l -L "${widget}" 2>/dev/null || echo))
  fi

  if [[ ${#result[@]} -ge 4 ]]; then
    local rawfunc=${result[4]}
    local wrapper="zvm_${widget}-wrapper"
    local rawcode=$(declare -f "$func" 2>/dev/null)
    local called=false
    [[ "$rawcode" == *"\$rawfunc"* ]] && { called=true }
    eval "$wrapper() { zvm_widget_wrapper $rawfunc $func $called \"\$@\" }"
    func=$wrapper
  fi

  # Only define the widget if zle is available
  if zvm_exist_command zle 2>/dev/null || command -v zle >/dev/null 2>&1; then
    zle -N "$widget" "$func" 2>/dev/null || true
  fi
}

# Get the keys typed to invoke this widget, as a literal string
function zvm_keys() {
  local keys=${ZVM_KEYS:-$KEYS}

  case "${ZVM_MODE}" in
    $ZVM_MODE_VISUAL)
      if [[ "$keys" != v* ]]; then
        keys="v${keys}"
      fi
      ;;
    $ZVM_MODE_VISUAL_LINE)
      if [[ "$keys" != V* ]]; then
        keys="V${keys}"
      fi
      ;;
  esac

  keys=${keys//$'\n'/$ZVM_ESCAPE_NEWLINE}
  keys=${keys// /$ZVM_ESCAPE_SPACE}

  echo $keys
}

# Check if a command exists
function zvm_exist_command() {
  command -v "$1" >/dev/null
}

# Execute commands
function zvm_exec_commands() {
  local commands="zvm_${1}_commands"
  commands=(${(P)commands})

  if zvm_exist_command "zvm_$1"; then
    eval "zvm_$1" ${@:2}
  fi

  for cmd in $commands; do
    if zvm_exist_command ${cmd}; then
      cmd="$cmd ${@:2}"
    fi
    eval $cmd
  done
}

# Convert string to hexadecimal
function zvm_string_to_hex() {
  local str= i=
  for ((i=1;i<=$#1;i++)); do
    str+=$(printf '%x' "'${1[$i]}")
  done
  echo "$str"
}

# Escape non-printed characters
function zvm_escape_non_printed_characters() {
  local str= i=
  for ((i=0;i<$#1;i++)); do
    local c=${1:$i:1}
    if [[ "$c" < ' ' ]]; then
      local ord=$(($(printf '%d' "'$c")+64))
      c=$(printf \\$(printf '%03o' $ord))
      str="${str}^${c}"
    elif [[ "$c" == '' ]]; then
      str="${str}^?"
    elif [[ "$c" == ' ' ]]; then
      str="${str}^@"
    else
      str="${str}${c}"
    fi
  done

  str=${str// /$ZVM_ESCAPE_SPACE}
  str=${str//$'\n'/$ZVM_ESCAPE_NEWLINE}

  echo -n $str
}

# Get the substr position in a string
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

# Check if cursor is at an empty line
function zvm_is_empty_line() {
  local cursor=${1:-$CURSOR}
  if [[ ${BUFFER:$cursor:1} == $'\n' &&
    ${BUFFER:$((cursor-1)):1} == $'\n' ]]; then
    return
  fi
  return 1
}

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

# Check if content is valid URL
function zvm_is_url() {
  local content="$1"
  if [[ "$content" =~ $ZVM_URL_REGEX ]]; then
    return 0
  fi
  return 1
}

# Check if content is a valid path
function zvm_is_path() {
  local content="$1"
  if [[ "$content" =~ '^~' ]]; then
    content="${HOME}${content:1}"
  fi
  if [[ -e "$content" ]]; then
    return 0
  fi
  return 1
}

# Select a word under the cursor
function zvm_select_in_word() {
  local cursor=${1:-$CURSOR}
  local buffer=${2:-$BUFFER}
  local bpos=$cursor epos=$cursor
  local pattern='[0-9a-zA-Z_]'

  if ! [[ "${buffer:$cursor:1}" =~ $pattern ]]; then
    pattern="[^${pattern:1:-1} ]"
  fi

  for ((; $bpos>=0; bpos--)); do
    [[ "${buffer:$bpos:1}" =~ $pattern ]] || break
  done
  for ((; $epos<$#buffer; epos++)); do
    [[ "${buffer:$epos:1}" =~ $pattern ]] || break
  done

  bpos=$((bpos+1))

  if (( epos > 0 )); then
    epos=$((epos-1))
  fi

  echo $bpos $epos
}

# Generate system report
function zvm_system_report() {
  local os_info=
  case "$(uname -s)" in
    Darwin)
      local product="$(sw_vers -productName)"
      local version="$(sw_vers -productVersion) ($(sw_vers -buildVersion))"
      os_info="${product} ${version}"
      ;;
    *) os_info="$(uname -s) ($(uname -r) $(uname -v) $(uname -m) $(uname -o))";;
  esac

  local term_info="${TERM_PROGRAM:-unknown} ${TERM_PROGRAM_VERSION:-unknown}"
  term_info="${term_info} (${TERM})"

  local zsh_frameworks=()

  if zvm_exist_command "omz"; then
    zsh_frameworks+=("oh-my-zsh $(omz version)")
  fi

  if zvm_exist_command "starship"; then
    zsh_frameworks+=("$(starship --version | head -n 1)")
  fi

  if zvm_exist_command "antigen"; then
    zsh_frameworks+=("$(antigen version | head -n 1)")
  fi

  if zvm_exist_command "zplug"; then
    zsh_frameworks+=("zplug $(zplug --version | head -n 1)")
  fi

  if zvm_exist_command "zinit"; then
    local version=$(zinit version \
      | head -n 1 \
      | sed -E $'s/(\033\[[a-zA-Z0-9;]+ ?m)//g')
    zsh_frameworks+=("${version}")
  fi

  local shell=$SHELL
  if [[ -z $shell ]]; then
    shell=zsh
  fi

  print - "- Terminal program: ${term_info}"
  print - "- Operating system: ${os_info}"
  print - "- ZSH framework: ${(j:, :)zsh_frameworks}"
  print - "- ZSH version: $($shell --version)"
  print - "- ZVM version: $(zvm_version | head -n 1)"
}
