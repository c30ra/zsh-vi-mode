# surround.zsh - Surround text object operations
# Add, change, delete, and navigate surrounds (quotes, brackets, etc.)

# Parse surround from keys
# Extracts action and surround character from key sequences
function zvm_parse_surround_keys() {
  local keys=${1:-${$(zvm_keys)//$ZVM_ESCAPE_SPACE/ }}
  local action=
  local surround=
  case "${keys}" in
    vS*) action=S; surround=${keys:2};;
    vsa*) action=a; surround=${keys:3};;
    vys*) action=y; surround=${keys:3};;
    s[dr]*) action=${keys:1:1}; surround=${keys:2};;
    [acd]s*) action=${keys:0:1}; surround=${keys:2};;
    [cdvy][ia]*) action=${keys:0:2}; surround=${keys:2};;
  esac
  echo $action ${surround// /$ZVM_ESCAPE_SPACE}
}

# Move around code structure (% command)
# Jump between matching surrounds like (), {}, [], <>
function zvm_move_around_surround() {
  local slen=
  local bpos=-1
  local epos=-1
  local i= s=
  for ((i=$CURSOR;i>=0;i--)); do
    # Check if it's one of the surrounds
    for s in {\',\",\`,\(,\[,\{,\<}; do
      slen=${#s}
      if [[ ${BUFFER:$i:$slen} == "$s" ]]; then
        bpos=$i
        break
      fi
    done
    if (($bpos == -1)); then
      continue
    fi
    # Search the nearest surround
    local ret=($(zvm_search_surround "$s"))
    if [[ -z ${ret[@]} ]]; then
      continue
    fi
    bpos=${ret[1]}
    epos=${ret[2]}
    # Move between the openning and close surrounds
    if (( $CURSOR > $((bpos-1)) )) && (( $CURSOR < $((bpos+slen)) )); then
      CURSOR=$epos
    else
      CURSOR=$bpos
    fi
    break
  done
}

# Match the surround pair from the part
# Returns matching opening and closing surround characters
function zvm_match_surround() {
  local bchar=${1// /$ZVM_ESCAPE_SPACE}
  local echar=$bchar
  case $bchar in
    '(') echar=')';;
    '[') echar=']';;
    '{') echar='}';;
    '<') echar='>';;
    ')') bchar='(';echar=')';;
    ']') bchar='[';echar=']';;
    '}') bchar='{';echar='}';;
    '>') bchar='<';echar='>';;
    "'") ;;
    '"') ;;
    '`') ;;
    *) return;;
  esac
  echo $bchar $echar
}

# Search surround from the string
# Finds surrounding characters around cursor position
function zvm_search_surround() {
  local ret=($(zvm_match_surround "$1"))
  local bchar=${${ret[1]//$ZVM_ESCAPE_SPACE/ }:- }
  local echar=${${ret[2]//$ZVM_ESCAPE_SPACE/ }:- }
  local bpos=$(zvm_substr_pos $BUFFER $bchar $CURSOR false)
  local epos=$(zvm_substr_pos $BUFFER $echar $CURSOR true)
  if [[ $bpos == $epos ]]; then
      epos=$(zvm_substr_pos $BUFFER $echar $((CURSOR+1)) true)
      if [[ $epos == -1 ]]; then
        epos=$(zvm_substr_pos $BUFFER $echar $((CURSOR-1)) false)
        if [[ $epos != -1 ]]; then
          local tmp=$epos; epos=$bpos; bpos=$tmp
        fi
      fi
  fi
  if [[ $bpos == -1 ]] || [[ $epos == -1 ]]; then
    return
  fi
  echo $bpos $epos $bchar $echar
}

# Select surround and highlight it in visual mode
# Selects text within or around surrounds for editing
function zvm_select_surround() {
  local ret=($(zvm_parse_surround_keys))
  local action=${1:-${ret[1]}}
  local surround=${2:-${ret[2]//$ZVM_ESCAPE_SPACE/ }}
  ret=($(zvm_search_surround ${surround}))
  if [[ ${#ret[@]} == 0 ]]; then
    zvm_exit_visual_mode
    return
  fi
  local bpos=${ret[1]}
  local epos=${ret[2]}
  if [[ ${action:1:1} == 'i' ]]; then
    ((bpos++))
  else
    ((epos++))
  fi
  MARK=$bpos; CURSOR=$epos-1

  # refresh for highlight redraw
  zle redisplay
}

# Change surround in vicmd or visual mode
# Modify surrounding characters (S, cs, ds, ys commands)
function zvm_change_surround() {
  local ret=($(zvm_parse_surround_keys))
  local action=${1:-${ret[1]}}
  local surround=${2:-${ret[2]//$ZVM_ESCAPE_SPACE/ }}
  local bpos=${3} epos=${4}
  local is_appending=false
  case $action in
    S|y|a) is_appending=true;;
  esac
  if $is_appending; then
    if [[ -z $bpos && -z $epos ]]; then
      ret=($(zvm_selection))
      bpos=${ret[1]} epos=${ret[2]}
    fi
  else
    ret=($(zvm_search_surround "$surround"))
    (( ${#ret[@]} )) || return
    bpos=${ret[1]} epos=${ret[2]}
    zvm_highlight custom $bpos $(($bpos+1))
    zvm_highlight custom $epos $(($epos+1))
  fi
  local key=
  case $action in
    c|r)
      zvm_enter_oppend_mode
      read -k 1 key
      zvm_exit_oppend_mode
      ;;
    S|y|a)
      if [[ -z $surround ]]; then
        zvm_enter_oppend_mode
        read -k 1 key
        zvm_exit_oppend_mode
      else
        key=$surround
      fi
      if [[ $ZVM_MODE == $ZVM_MODE_VISUAL ]]; then
        zle visual-mode
      fi
      ;;
  esac

  # Check if it is ESCAPE key (<ESC> or ZVM_VI_ESCAPE_BINDKEY)
  case "$key" in
    $'\e'|"${ZVM_VI_ESCAPE_BINDKEY//\^\[/$'\e'}")
      zvm_highlight clear
      return
  esac

  # Start changing surround
  ret=($(zvm_match_surround "$key"))
  local bchar=${${ret[1]//$ZVM_ESCAPE_SPACE/ }:-$key}
  local echar=${${ret[2]//$ZVM_ESCAPE_SPACE/ }:-$key}
  local value=$($is_appending && echo 0 || echo 1 )
  local head=${BUFFER:0:$bpos}
  local body=${BUFFER:$((bpos+value)):$((epos-(bpos+value)))}
  local foot=${BUFFER:$((epos+value))}
  BUFFER="${head}${bchar}${body}${echar}${foot}"

  # Clear highliht
  zvm_highlight clear

  case $action in
    S|y|a) zvm_select_vi_mode $ZVM_MODE_NORMAL;;
  esac
}

# Change surround text object
# Change or delete text within or around surrounds (ci(, da", etc.)
function zvm_change_surround_text_object() {
  local ret=($(zvm_parse_surround_keys))
  local action=${1:-${ret[1]}}
  local surround=${2:-${ret[2]//$ZVM_ESCAPE_SPACE/ }}
  ret=($(zvm_search_surround "${surround}"))
  if [[ ${#ret[@]} == 0 ]]; then
    zvm_select_vi_mode $ZVM_MODE_NORMAL
    return
  fi
  local bpos=${ret[1]}
  local epos=${ret[2]}
  if [[ ${action:1:1} == 'i' ]]; then
    ((bpos++))
  else
    ((epos++))
  fi
  CUTBUFFER=${BUFFER:$bpos:$(($epos-$bpos))}
  case ${action:0:1} in
    c)
      BUFFER="${BUFFER:0:$bpos}${BUFFER:$epos}"
      CURSOR=$bpos
      zvm_select_vi_mode $ZVM_MODE_INSERT
      ;;
    d)
      BUFFER="${BUFFER:0:$bpos}${BUFFER:$epos}"
      CURSOR=$bpos
      ;;
  esac
}
