# ui.zsh - User interface styling
# Cursor styling and region highlighting for visual modes

# Highlight visual selection and surrounds
# Updates region_highlight array with visual selection or custom highlights
function zvm_highlight() {
  local opt=${1:-mode}
  local region=()
  local redraw=false

  # Handle region by the option
  case "$opt" in
    mode)
      case "$ZVM_MODE" in
        $ZVM_MODE_VISUAL|$ZVM_MODE_VISUAL_LINE)
          local ret=($(zvm_calc_selection))
          local bpos=$((ret[1])) epos=$((ret[2]))
          local bg=$ZVM_VI_HIGHLIGHT_BACKGROUND
          local fg=$ZVM_VI_HIGHLIGHT_FOREGROUND
          local es=$ZVM_VI_HIGHLIGHT_EXTRASTYLE
          region=("$bpos $epos fg=$fg,bg=$bg,$es")
          ;;
      esac
      redraw=true
      ;;
    custom)
      local bpos=$2 epos=$3
      local bg=${4:-$ZVM_VI_HIGHLIGHT_BACKGROUND}
      local fg=${5:-$ZVM_VI_HIGHLIGHT_FOREGROUND}
      local es=${6:-$ZVM_VI_HIGHLIGHT_EXTRASTYLE}
      region=("${ZVM_REGION_HIGHLIGHT[@]}")
      region+=("$bpos $epos fg=$fg,bg=$bg,$es")
      redraw=true
      ;;
    clear)
      zle redisplay
      redraw=true
      ;;
    redraw) redraw=true;;
  esac

  # Update region highlight
  if (( $#region > 0 )) || [[ "$opt" == 'clear' ]]; then

    # Remove old region highlight
    local rawhighlight=()
    local i= j=
    for ((i=1; i<=${#region_highlight[@]}; i++)); do
      local raw=true
      local spl=(${(@s/ /)region_highlight[i]})
      local pat="${spl[1]} ${spl[2]}"
      for ((j=1; j<=${#ZVM_REGION_HIGHLIGHT[@]}; j++)); do
        if [[ "$pat" == "${ZVM_REGION_HIGHLIGHT[j]:0:$#pat}" ]]; then
          raw=false
          break
        fi
      done
      if $raw; then
        rawhighlight+=("${region_highlight[i]}")
      fi
    done

    # Assign new region highlight
    ZVM_REGION_HIGHLIGHT=("${region[@]}")
    region_highlight=("${rawhighlight[@]}" "${ZVM_REGION_HIGHLIGHT[@]}")
  fi

  # Check if we need to refresh the region highlight
  if $redraw; then
    zle -R
  fi
}

# Set terminal cursor style/shape
# Outputs escape sequence to set cursor appearance
function zvm_set_cursor() {
  # Term of vim isn't supported
  if [[ -n $VIM ]]; then
    return
  fi

  echo -ne "$1"
}

# Get the escape sequence for cursor style
# Translates cursor style constants to terminal escape sequences
function zvm_cursor_style() {
  local style=${(L)1}
  local term=${2:-$ZVM_TERM}

  case $term in
    # For xterm and rxvt and their derivatives use the same escape
    # sequences as the VT520 terminal. And screen, konsole, alacritty,
    # st and foot implement a superset of VT100 and VT100, they support
    # 256 colors the same way xterm does.
    xterm*|rxvt*|screen*|tmux*|konsole*|alacritty*|st*|foot*|wezterm)
      case $style in
        $ZVM_CURSOR_BLOCK) style='\e[2 q';;
        $ZVM_CURSOR_UNDERLINE) style='\e[4 q';;
        $ZVM_CURSOR_BEAM) style='\e[6 q';;
        $ZVM_CURSOR_BLINKING_BLOCK) style='\e[1 q';;
        $ZVM_CURSOR_BLINKING_UNDERLINE) style='\e[3 q';;
        $ZVM_CURSOR_BLINKING_BEAM) style='\e[5 q';;
        $ZVM_CURSOR_USER_DEFAULT) style='\e[0 q';;
      esac
      ;;
    *) style='\e[0 q';;
  esac

  # Restore default cursor color
  if [[ $style == '\e[0 q' ]]; then
    local old_style=

    case $ZVM_MODE in
      $ZVM_MODE_INSERT) old_style=$ZVM_INSERT_MODE_CURSOR;;
      $ZVM_MODE_NORMAL) old_style=$ZVM_NORMAL_MODE_CURSOR;;
      $ZVM_MODE_VISUAL) old_style=$ZVM_VISUAL_MODE_CURSOR;;
      $ZVM_MODE_VISUAL_LINE) old_style=$ZVM_VISUAL_LINE_MODE_CURSOR;;
    esac

    if [[ $old_style =~ '\e\][0-9]+;.+\a' ]]; then
      style=$style'\e\e]112\a'
    fi
  fi

  echo $style
}

# Update cursor based on current VI mode
# Updates cursor style when entering different VI modes
function zvm_update_cursor() {

  # Check if we need to update the cursor style
  $ZVM_CURSOR_STYLE_ENABLED || return

  local mode=$1
  local shape=

  # Check if it is operator pending mode
  if $ZVM_OPPEND_MODE; then
    mode=opp
    shape=$(zvm_cursor_style $ZVM_OPPEND_MODE_CURSOR)
  fi

  # Get cursor shape by the mode
  case "${mode:-$ZVM_MODE}" in
    $ZVM_MODE_NORMAL)
      shape=$(zvm_cursor_style $ZVM_NORMAL_MODE_CURSOR)
      ;;
    $ZVM_MODE_INSERT)
      shape=$(zvm_cursor_style $ZVM_INSERT_MODE_CURSOR)
      ;;
    $ZVM_MODE_VISUAL)
      shape=$(zvm_cursor_style $ZVM_VISUAL_MODE_CURSOR)
      ;;
    $ZVM_MODE_VISUAL_LINE)
      shape=$(zvm_cursor_style $ZVM_VISUAL_LINE_MODE_CURSOR)
      ;;
  esac

  if [[ $shape ]]; then
    zvm_set_cursor $shape
  fi
}

# Updates highlight region
# Refreshes highlighting for visual selections
function zvm_update_highlight() {
  case "$ZVM_MODE" in
    $ZVM_MODE_VISUAL|$ZVM_MODE_VISUAL_LINE)
      zvm_highlight
      ;;
  esac
}

# Update terminal mode indicator for terminals like WezTerm
# Sends OSC sequence to indicate current VI mode
function zvm_update_terminal_mode() {
  # Skip if not supported or in non-interactive environment
  [[ -z "$TERM" ]] && return
  [[ "$TERM" == "dumb" ]] && return
  
  local mode_name=""
  case "$ZVM_MODE" in
    $ZVM_MODE_NORMAL)
      mode_name="NORMAL"
      ;;
    $ZVM_MODE_INSERT)
      mode_name="INSERT"
      ;;
    $ZVM_MODE_VISUAL)
      mode_name="VISUAL"
      ;;
    $ZVM_MODE_VISUAL_LINE)
      mode_name="VISUAL-LINE"
      ;;
    $ZVM_MODE_REPLACE)
      mode_name="REPLACE"
      ;;
  esac
  
  # Send OSC 1337 (iTerm) and other compatible sequences for mode indication
  # Format: OSC 1337 ; SetUserVar=name=value ST
  if [[ -n "$mode_name" ]]; then
    # For terminals that support it, send the mode via OSC sequence
    printf "\033]1337;SetUserVar=zvm_mode=%s\007" "$mode_name"
  fi
}
