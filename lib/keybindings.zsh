# Keybinding management for zsh-vi-mode
# Handles key reading and binding functionality

# Find the widget on a specified bindkey
function zvm_find_bindkey_widget() {
  local keymap=${1:-}
  local keys=${2:-}
  local prefix_mode=${3:-false}
  retval=()

  if $prefix_mode; then
    local pos=0
    local spos=3
    local prefix_keys=$keys

    if [[ $prefix_keys ]]; then
      prefix_keys=${prefix_keys:0:-1}

      if [[ ${prefix_keys: -1} == '\' ]]; then
        prefix_keys=${prefix_keys:0:-1}
      fi
    fi

    local result=$(bindkey -M ${keymap} -p "$prefix_keys")$'\n'

    local i=
    for ((i=$spos;i<$#result;i++)); do
      case "${result:$i:1}" in
        ' ') spos=$i; i=$i+1; continue;;
        [$'\n']);;
        *) continue;;
      esac

      if [[ "${result:$((pos+1)):$#keys}" == "$keys" ]]; then
        local k=${result:$((pos+1)):$((spos-pos-2))}
        k=${k// /$ZVM_ESCAPE_SPACE}
        retval+=($k ${result:$((spos+1)):$((i-spos-1))})
      fi

      pos=$i+1
      i=$i+3
    done
  else
    local result=$(bindkey -M ${keymap} "$keys")
    if [[ "${result: -14}" == ' undefined-key' ]]; then
      return
    fi

    local i=
    for ((i=$#result;i>=0;i--)); do
      [[ "${result:$i:1}" == ' ' ]] || continue

      local k=${result:1:$i-2}
      k=${k// /$ZVM_ESCAPE_SPACE}
      retval+=($k ${result:$i+1})

      break
    done
  fi
}

# Read keys for retrieving widget
function zvm_readkeys() {
  local keymap=$1
  local key=${2:-$(zvm_keys)}
  local keys=
  local widget=
  local result=
  local pattern=
  local timeout=

  while :; do
    if [[ "$key" == $'\e' ]]; then
      while :; do
        local k=
        read -t $ZVM_ESCAPE_KEYTIMEOUT -k 1 k || break
        key="${key}${k}"
      done
    fi

    keys="${keys}${key}"

    if [[ -n "$key" ]]; then
      local k=$(zvm_escape_non_printed_characters "${key}")

      k=${k//\"/\\\"}
      k=${k//\`/\\\`}
      k=${k//$ZVM_ESCAPE_SPACE/ }

      pattern="${pattern}${k}"
    fi

    zvm_find_bindkey_widget $keymap "$pattern" true
    result=(${retval[@]})

    case ${#result[@]} in
      2) key=; widget=${result[2]}; break;;
      0) break;;
    esac

    if [[ "${keys}" == $'\e' ]]; then
      timeout=$ZVM_ESCAPE_KEYTIMEOUT
      local i=
      for ((i=1; i<=${#result[@]}; i=i+2)); do
        if [[ "${result[$i]}" =~ '^\^\[\[?[A-Z0-9]*~?\^\[' ]]; then
          timeout=$ZVM_KEYTIMEOUT
          break
        fi
      done
    else
      timeout=$ZVM_KEYTIMEOUT
    fi

    key=
    if [[ "${result[1]}" == "${pattern}" ]]; then
      widget=${result[2]}
      read -t $timeout -k 1 key || break
    else
      zvm_enter_oppend_mode
      read -k 1 key
    fi
  done

  if $ZVM_OPPEND_MODE; then
    zvm_exit_oppend_mode
  fi

  if [[ -z "$key" ]]; then
    retval=(${keys} $widget)
  else
    retval=(${keys:0:-$#key} $widget $key)
  fi
}

# Add key bindings
function zvm_bindkey() {
  local keymap=${1:-}
  local keys=${2:-}
  local widget=${3:-}
  local params=${4:-}
  local key=

  [[ -z $widget ]] && return

  if [[ ${ZVM_LAZY_KEYBINDINGS_LIST+x} && ${keymap} != viins ]]; then
    keys=${keys//\"/\\\"}
    keys=${keys//\`/\\\`}
    ZVM_LAZY_KEYBINDINGS_LIST+=(
      "${keymap} \"${keys}\" ${widget} \"${params}\""
    )
    return
  fi

  if [[ $ZVM_READKEY_ENGINE == $ZVM_READKEY_ENGINE_NEX ]]; then
    if [[ ${#keys} -gt 1 && "${keys:0:1}" == '^' ]]; then
      key=${keys:0:2}
    else
      key=${keys:0:1}

      if [[ "$keymap" == "viins" ]]; then
        bindkey -M isearch "${key}" self-insert
      fi
    fi
    bindkey -M "$keymap" "${key}" zvm_readkeys_handler
  fi

  if [[ -n $params ]]; then
    local suffix=$(zvm_string_to_hex $params)
    eval "$widget:$suffix() { $widget $params }"
    widget="$widget:$suffix"
    zvm_define_widget $widget
  fi

  bindkey -M $keymap "${keys}" $widget
}
