#!/usr/bin/env bash
set -e

# -------------------------------
# Detect user's default shell
# -------------------------------

USER_SHELL=$(basename "$SHELL")

case "$USER_SHELL" in
  zsh)
    SHELL_RC="$HOME/.zshrc"
    SHELL_TYPE="zsh"
    ;;
  bash)
    SHELL_RC="$HOME/.bashrc"
    SHELL_TYPE="bash"
    ;;
  *)
    echo "❌ Unsupported shell. Only Bash or Zsh are supported."
    exit 1
    ;;
esac

echo "🔍 Detected shell: $SHELL_TYPE ($SHELL_RC)"

# -------------------------------
# BSH directory and loader
# -------------------------------

BSH_DIR="$HOME/.bsh"
LOAD_FILE="$BSH_DIR/load.sh"
LOAD_CMD='[ -s "$HOME/.bsh/load.sh" ] && source "$HOME/.bsh/load.sh"'

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

if [ "$SHELL_TYPE" = "zsh" ]; then
  if command -v zsh >/dev/null 2>&1; then
    echo "➡️ Loading BSH scripts in current session via Zsh..."
    zsh -c "source $LOAD_FILE"
    echo "✅ BSH loaded in current session."
  else
    echo "⚠️ Zsh binary not found in PATH"
  fi
else
  echo "➡️ Loading BSH scripts for Bash..."
  [ -f "$BSH_DIR/bash_tools.sh" ] && source "$BSH_DIR/bash_tools.sh"
  echo "✅ Bash-compatible BSH loaded in current session."
fi

echo ""
echo "➡️ Open a new terminal to load BSH automatically in future sessions."
echo "   Or run: source $SHELL_RC"