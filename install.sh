#!/usr/bin/env bash
set -e

ZSHRC="$HOME/.zshrc"
BASHRC="$HOME/.bashrc"
BSH_DIR="$HOME/.bsh"
LOAD_FILE="$BSH_DIR/load.zsh"
LOAD_CMD='[ -s "$HOME/.bsh/load.zsh" ] && source "$HOME/.bsh/load.zsh"'

# -------------------------------
# Detect current script location
# -------------------------------

if [ ! -f "$LOAD_FILE" ]; then
  echo "❌ Loader not found: $LOAD_FILE"
  echo "Please make sure the BSH repository is cloned to $BSH_DIR"
  exit 1
fi

# -------------------------------
# Detect current shell rc file
# -------------------------------

if [ -n "$ZSH_VERSION" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
  SHELL_RC="$HOME/.bashrc"
else
  echo "❌ Unsupported shell. Only Bash or Zsh are supported."
  exit 1
fi

# -------------------------------
# Add loader to shell rc if missing
# -------------------------------

if ! grep -Fxq "$LOAD_CMD" "$SHELL_RC"; then
  echo "" >> "$SHELL_RC"
  echo "# BSH autoload" >> "$SHELL_RC"
  echo "$LOAD_CMD" >> "$SHELL_RC"
  echo "✅ BSH loader added to $SHELL_RC"
else
  echo "⚙️ BSH loader already exists in $SHELL_RC"
fi

# -------------------------------
# Run loader immediately
# -------------------------------

source "$LOAD_FILE"
echo "✅ BSH loaded into current shell session."
echo "➡️ Open a new terminal to load BSH automatically in future sessions."