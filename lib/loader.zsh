# zsh-vi-mode.zsh -- Modularized version
# A better and friendly vi(vim) mode plugin for Zsh
# https://github.com/jeffreytse/zsh-vi-mode
#
# Copyright (c) 2020 Jeffrey Tse
# MIT License

# Avoid sourcing plugin multiple times
command -v 'zvm_version' >/dev/null && return

# Determine absolute directory of this loader file robustly whether sourced or executed
# Prefer the zsh-specific magic parameter to get the current file path when sourced.
local ZVM_SCRIPT_PATH
ZVM_SCRIPT_PATH="${(%):-%N}"

# If %N is `-` or empty (unexpected), fall back to $0
if [[ -z "$ZVM_SCRIPT_PATH" || "$ZVM_SCRIPT_PATH" == "-" ]]; then
  ZVM_SCRIPT_PATH="$0"
fi

# Absolute directory of the loader script
ZVM_SCRIPT_DIR="${ZVM_SCRIPT_PATH:A:h}"

# Determine project root: if this loader resides in a `lib` directory, use its parent
if [[ "${ZVM_SCRIPT_DIR:t}" == "lib" ]]; then
  ZVM_ROOT="${ZVM_SCRIPT_DIR:A:h}"
else
  ZVM_ROOT="$ZVM_SCRIPT_DIR"
fi

# If running from plugin.zsh's parent layout, adjust path (compat)
if [[ "$ZVM_ROOT" == *".." ]]; then
  ZVM_ROOT="${ZVM_ROOT%/*}"
fi

# Load modules in dependency order from project root
if [[ -d "$ZVM_ROOT/lib" ]]; then
  # Load constants first (no dependencies)
  source "$ZVM_ROOT/lib/constants.zsh"

  # Load utilities (depends on constants)
  source "$ZVM_ROOT/lib/utils.zsh"

  # Load mode manager (depends on constants, utils)
  if [[ -f "$ZVM_ROOT/lib/mode-manager.zsh" ]]; then
    source "$ZVM_ROOT/lib/mode-manager.zsh"
  fi

  # Load other modules if they exist (they'll be added as we refactor)
  for module in "$ZVM_ROOT"/lib/{keybindings,editor,repeat,surround,keywords,ui,clipboard,url,navigation,handlers,zle-hooks,init}.zsh; do
    [[ -f "$module" ]] && source "$module"
  done
else
  # Fallback: load everything from the monolithic file if lib directory doesn't exist
  source "${0:h}/zsh-vi-mode-full.zsh"
  return
fi

# Only proceed with initialization if lib modules are loaded
# (Initialize if not using lib directory)
if ! command -v 'zvm_init' >/dev/null 2>&1; then
  # Load initialization from init module or full file
  if [[ -f "$ZVM_SCRIPT_DIR/lib/init.zsh" ]]; then
    source "$ZVM_SCRIPT_DIR/lib/init.zsh"
  fi
fi

# Load config by calling the config function
if zvm_exist_command "$ZVM_CONFIG_FUNC"; then
  $ZVM_CONFIG_FUNC
fi

# Initialize this plugin according to the mode
case $ZVM_INIT_MODE in
  sourcing) zvm_init;;
  *) precmd_functions+=(zvm_init);;
esac
