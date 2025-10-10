#!/usr/bin/env bash
set -e

# -------------------------------
# Detect shell and RC file
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
# BSH directory and loader
# -------------------------------

BSH_DIR="$HOME/.bsh"
LOAD_FILE="$BSH_DIR/load.zsh"
LOAD_CMD='[ -s "$HOME/.bsh/load.zsh" ] && source "$HOME/.bsh/load.zsh"'

# -------------------------------
# Verify BSH directory
# -------------------------------
if [ ! -d "$BSH_DIR" ]; then
    echo "❌ BSH directory not found: $BSH_DIR"
    exit 1
fi

# -------------------------------
# Verify loader exists
# -------------------------------

if [ ! -f "$LOAD_FILE" ]; then
  echo "❌ Loader not found: $LOAD_FILE"
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
# Load scripts immediately
# -------------------------------

if command -v zsh >/dev/null 2>&1; then
    echo "➡️ Loading BSH scripts in current session via Zsh..."
    zsh -c "source $LOAD_FILE"
    echo "✅ BSH loaded in current session."
else
    echo "⚠️ Zsh not found. Adding loader to Bash only."
    [ -f "$BSH_DIR/bash_tools.sh" ] && source "$BSH_DIR/bash_tools.sh"
    echo "✅ Bash-compatible BSH loaded in current session."
fi

echo "➡️ Open a new terminal to load BSH automatically in future sessions."