# --------------------------------
# Shell detection
# --------------------------------

if [ -n "$ZSH_VERSION" ]; then
  __SHELL_TYPE="zsh"
elif [ -n "$BASH_VERSION" ]; then
  __SHELL_TYPE="bash"
else
  echo "⚠️  Unsupported shell. Use Bash or Zsh." >&2
  return 1 2>/dev/null || exit 1
fi

# --------------------------------
# Global state
# --------------------------------

if [[ "$__SHELL_TYPE" == "zsh" ]]; then
  typeset -A git_file_map
  typeset -i file_counter=1
else
  declare -A git_file_map
  declare -i file_counter=1
fi