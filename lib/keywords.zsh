# keywords.zsh - Keyword switching functionality
# Increment/decrement numbers, booleans, dates, and other keywords

# Switch keyword under cursor
# Main dispatcher for switching keywords (^A and ^X commands)
function zvm_switch_keyword() {
  local bpos= epos= cpos=$CURSOR

  # Move cursor to handle signed numbers
  if [[ ${BUFFER:$cpos:2} =~ [+-][0-9] ]]; then
    if [[ $cpos == 0 || ${BUFFER:$((cpos-1)):1} =~ [^0-9] ]]; then
      cpos=$((cpos+1))
    fi
  elif [[ ${BUFFER:$cpos:2} =~ [+-][a-zA-Z] ]]; then
    if [[ $cpos == 0 || ${BUFFER:$((cpos-1)):1} == ' ' ]]; then
      cpos=$((cpos+1))
    fi
  fi

  local result=($(zvm_select_in_word $cpos))
  bpos=${result[1]} epos=$((${result[2]}+1))

  # Move backward the cursor
  if [[ $bpos != 0 && ${BUFFER:$((bpos-1)):1} == [+-] ]]; then
    bpos=$((bpos-1))
  fi

  local word=${BUFFER:$bpos:$((epos-bpos))}
  local keys=$(zvm_keys)

  if [[ $keys == '' ]]; then
    local increase=true
  else
    local increase=false
  fi

  # Execute extra commands
  for handler in $zvm_switch_keyword_handlers; do
    if ! zvm_exist_command ${handler}; then
      continue
    fi

    result=($($handler $word $increase));

    if (( $#result == 0 )); then
      continue
    fi

    epos=$(( bpos + ${result[3]} ))
    bpos=$(( bpos + ${result[2]} ))

    if (( cpos < bpos )) || (( cpos >= epos )); then
      continue
    fi

    # Save to history and only keep some recent records
    zvm_switch_keyword_history+=("${handler}:${word}")
    zvm_switch_keyword_history=("${zvm_switch_keyword_history[@]: -10}")

    BUFFER="${BUFFER:0:$bpos}${result[1]}${BUFFER:$epos}"
    CURSOR=$((bpos + ${#result[1]} - 1))

    zle reset-prompt
    return
  done
}

# Switch number keyword (hex, binary, decimal)
# Increment/decrement numbers in various bases
function zvm_switch_number() {
  local word=$1
  local increase=${2:-true}
  local result= bpos= epos=

  # Hexadecimal
  if [[ $word =~ [^0-9]?(0[xX][0-9a-fA-F]*) ]]; then
    local number=${match[1]}
    local prefix=${number:0:2}
    bpos=$((mbegin-1)) epos=$mend

    local lower=true
    if [[ $number =~ [A-Z][0-9]*$ ]]; then
      lower=false
    fi

    # Fix the number truncated after 15 digits issue
    if (( $#number > 17 )); then
      local d=$(($#number - 15))
      local h=${number:0:$d}
      number="0x${number:$d}"
    fi

    local p=$(($#number - 2))

    if $increase; then
      if (( $number == 0x${(l:15::f:)} )); then
        h=$(([##16]$h+1))
        h=${h: -1}
        number=${(l:15::0:)}
      else
        h=${h:2}
        number=$(([##16]$number + 1))
      fi
    else
      if (( $number == 0 )); then
        if (( ${h:-0} == 0 )); then
          h=f
        else
          h=$(([##16]$h-1))
          h=${h: -1}
        fi
        number=${(l:15::f:)}
      else
        h=${h:2}
        number=$(([##16]$number - 1))
      fi
    fi

    # Padding with zero
    if (( $#number < $p )); then
      number=${(l:$p::0:)number}
    fi

    result="${h}${number}"

    # Transform the case
    if $lower; then
      result="${(L)result}"
    fi

    result="${prefix}${result}"

  # Binary
  elif [[ $word =~ [^0-9]?(0[bB][01]*) ]]; then
    local number=${match[1]}
    local prefix=${number:0:2}
    bpos=$((mbegin-1)) epos=$mend

    # Fix the number truncated after 63 digits issue
    if (( $#number > 65 )); then
      local d=$(($#number - 63))
      local h=${number:0:$d}
      number="0b${number:$d}"
    fi

    local p=$(($#number - 2))

    if $increase; then
      if (( $number == 0b${(l:63::1:)} )); then
        h=$(([##2]$h+1))
        h=${h: -1}
        number=${(l:63::0:)}
      else
        h=${h:2}
        number=$(([##2]$number + 1))
      fi
    else
      if (( $number == 0b0 )); then
        if (( ${h:-0} == 0 )); then
          h=1
        else
          h=$(([##2]$h-1))
          h=${h: -1}
        fi
        number=${(l:63::1:)}
      else
        h=${h:2}
        number=$(([##2]$number - 1))
      fi
    fi

    # Padding with zero
    if (( $#number < $p )); then
      number=${(l:$p::0:)number}
    fi

    result="${prefix}${number}"

  # Decimal
  elif [[ $word =~ ([-+]?[0-9]+) ]]; then
    local number=${match[1]}
    bpos=$((mbegin-1)) epos=$mend

    if $increase; then
      result=$(($number + 1))
    else
      result=$(($number - 1))
    fi

    # Check if need the plus sign prefix
    if [[ ${word:$bpos:1} == '+' ]]; then
      result="+${result}"
    fi
  fi

  if [[ $result ]]; then
    echo $result $bpos $epos
  fi
}

# Switch boolean keyword
# Toggle true/false, yes/no, on/off, etc.
function zvm_switch_boolean() {
  local word=$1
  local increase=$2
  local result=
  local bpos=0 epos=$#word

  # Remove option prefix
  if [[ $word =~ (^[+-]{0,2}) ]]; then
    local prefix=${match[1]}
    bpos=$mend
    word=${word:$bpos}
  fi

  case ${(L)word} in
    true) result=false;;
    false) result=true;;
    yes) result=no;;
    no) result=yes;;
    on) result=off;;
    off) result=on;;
    y) result=n;;
    n) result=y;;
    t) result=f;;
    f) result=t;;
    *) return;;
  esac

  # Transform the case
  if [[ $word =~ ^[A-Z]+$ ]]; then
    result=${(U)result}
  elif [[ $word =~ ^[A-Z] ]]; then
    result=${(U)result:0:1}${result:1}
  fi

  echo $result $bpos $epos
}

# Switch weekday keyword
# Cycle through days of the week
function zvm_switch_weekday() {
  local word=$1
  local increase=$2
  local result=${(L)word}
  local weekdays=(
    sunday
    monday
    tuesday
    wednesday
    thursday
    friday
    saturday
  )

  local i=1

  for ((; i<=${#weekdays[@]}; i++)); do
    if [[ ${weekdays[i]:0:$#result} == ${result} ]]; then
      result=${weekdays[i]}
      break
    fi
  done

  # Return if no match
  if (( i > ${#weekdays[@]} )); then
    return
  fi

  if $increase; then
    if (( i == ${#weekdays[@]} )); then
      i=1
    else
      i=$((i+1))
    fi
  else
    if (( i == 1 )); then
      i=${#weekdays[@]}
    else
      i=$((i-1))
    fi
  fi

  # Handle abbreviation
  if (($#word == 3)); then
    result=${weekdays[i]:0:3}
  else
    result=${weekdays[i]}
  fi

  # Transform the case
  if [[ $word =~ ^[A-Z]+$ ]]; then
    result=${(U)result}
  elif [[ $word =~ ^[A-Z] ]]; then
    result=${(U)result:0:1}${result:1}
  fi

  echo $result 0 $#word
}

# Switch month keyword
# Cycle through months of the year
function zvm_switch_month() {
  local word=$1
  local increase=$2
  local result=${(L)word}
  local months=(
    january
    february
    march
    april
    may
    june
    july
    august
    september
    october
    november
    december
  )

  local i=1

  for ((; i<=${#months[@]}; i++)); do
    if [[ ${months[i]:0:$#result} == ${result} ]]; then
      result=${months[i]}
      break
    fi
  done

  # Return if no match
  if (( i > ${#months[@]} )); then
    return
  fi

  if $increase; then
    if (( i == ${#months[@]} )); then
      i=1
    else
      i=$((i+1))
    fi
  else
    if (( i == 1 )); then
      i=${#months[@]}
    else
      i=$((i-1))
    fi
  fi

  # Handle abbreviation
  local lastlen=0
  local last="${zvm_switch_keyword_history[-1]}"
  local funcmark="${funcstack[1]}:"
  if [[ "$last" =~ "^${funcmark}" ]]; then
    lastlen=$(($#last - $#funcmark))
  fi

  if [[ "$result" == "may" ]]; then
    if (($lastlen == 3)); then
      result=${months[i]:0:3}
    else
      result=${months[i]}
    fi
  else
    if (($#word == 3)); then
      result=${months[i]:0:3}
    else
      result=${months[i]}
    fi
  fi

  # Transform the case
  if [[ $word =~ ^[A-Z]+$ ]]; then
    result=${(U)result}
  elif [[ $word =~ ^[A-Z] ]]; then
    result=${(U)result:0:1}${result:1}
  fi

  echo $result 0 $#word
}
