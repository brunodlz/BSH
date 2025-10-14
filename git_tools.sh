# ===== GIT ADVANCED =====

# --------------------------------
# Colors
# --------------------------------

green=$'\033[32m'
red=$'\033[31m'
orange=$'\033[38;5;214m'
cyan=$'\033[36m'
reset=$'\033[0m'

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

# --------------------------------
# Git status
# --------------------------------

git_status() {
  local -a staged unstaged untracked
  git_file_map_from_status staged unstaged untracked

  file_counter=1
  print_git_section "$green"  "Changes to be committed:"        "${staged[@]}"
  print_git_section "$orange" "Changes not staged for commit:"  "${unstaged[@]}"
  print_git_section "$cyan"   "Untracked files:"                "${untracked[@]}"
}

# --------------------------------
# Git add
# --------------------------------

git_add() {
  local root files=() indexes=()
  local staged_files unstaged_files

  # Set the root directory of the git repository
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "❌ Not a Git repository"
    return 1
  }

  # Get all staged and unstaged files
  staged_files=("${(@f)$(git diff --cached --name-only | sed '/^$/d' | tr -d '\r')}")
  unstaged_files=("${(@f)$(git diff --name-only | sed '/^$/d' | tr -d '\r')}")

  # Combine and remove duplicates
  for f in "${staged_files[@]}" "${unstaged_files[@]}"; do
    [[ -n "$f" ]] && files+=("$f")
  done
  files=(${(u)files})

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "✅ No files to add"
    return 0
  fi

  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: ga <number(s) or interval(s)>"
    echo "Ex: ga 1 3 5-7"
    return 1
  fi

  for arg in "$@"; do
    if [[ "$arg" == *-* ]]; then
      local start end
      IFS='-' read -r start end <<< "$arg"
      if [[ ! "$start" =~ ^[0-9]+$ ]] || [[ ! "$end" =~ ^[0-9]+$ ]]; then
        echo "⚠️ Invalid interval: $arg"
        continue
      fi
      for ((i=start; i<=end; i++)); do
        indexes+=($i)
      done
    else
      if [[ ! "$arg" =~ ^[0-9]+$ ]]; then
        echo "⚠️ Invalid number: $arg"
        continue
      fi
      indexes+=($arg)
    fi
  done

  # Remove duplicates and sort indexes
  indexes=(${(nu)indexes})

  for i in "${indexes[@]}"; do
    if (( i >= 1 && i <= ${#files[@]} )); then
      local file="${files[$((i))]}"

      if [[ -z "$file" ]]; then
        echo "⚠️ Skipping empty entry at index $i"
        continue
      fi

      local abs_path="$root/$file"

      if [[ ! -e "$abs_path" ]]; then
        echo "⚠️ File not found: $file"
        continue
      fi

      # Re-adds modified files (even if they are already staged)
      (cd "$root" && git add -- "$file")
      echo "➕ Added: $file"
    else
      echo "⚠️ Invalid number: $i (range: 1-${#files[@]})"
    fi
  done
}


# --------------------------------
# Git diff
# --------------------------------

git_diff() {
  local num="$1"

  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: gd <number>" >&2
    echo "Ex: gd 1" >&2
    return 1
  fi

  if [[ ${#git_file_map[@]} -eq 0 ]]; then
    git_file_map_from_status
  fi

  if [[ -z "${git_file_map[$num]}" ]]; then
    echo "⚠️ Number out of range: $num (1-${#git_file_map[@]})" >&2
    return 1
  fi

  local file=$(_extract_filename "${git_file_map[$num]}")

  git diff --color=always -- "$file" | less -R
}

# --------------------------------
# Git reset
# --------------------------------

git_reset() {
  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: gr <numbers>" >&2
    echo "Ex: gr 1 2 3" >&2
    return 1
  fi

  if [[ ${#git_file_map[@]} -eq 0 ]]; then
    git_file_map_from_status
  fi

  local -a files_to_reset
  local file

  for i in "$@"; do
    if [[ -z "${git_file_map[$i]}" ]]; then
      echo "⚠️ Number out of range: $i (1-${#git_file_map[@]})" >&2
      return 1
    fi

    file=$(_extract_filename "${git_file_map[$i]}")
    files_to_reset+=("$file")
  done

  if git reset HEAD -- "${files_to_reset[@]}" >/dev/null; then
    for file in "${files_to_reset[@]}"; do
      echo "🧹 Removed from stage: $file"
    done
  else
    echo "❌ Failed to reset files" >&2
    return 1
  fi
}

# ===============================================
# =================== Helpers ===================
# ===============================================

# --------------------------------------
# Git root
# --------------------------------------

get_git_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

# --------------------------------------
# Print
# --------------------------------------

print_git_section() {
  local color="$1"
  local title="$2"
  shift 2
  local items=("$@")
  local pipe="${color}|${reset}"

  [[ ${#items[@]} -eq 0 ]] && return

  printf "%b ➤ %s\n" "$pipe" "$title"
  printf "%b\n" "$pipe"

  for item in "${items[@]}"; do
    printf "%b   [%d] %s%b\n" "$pipe" "$file_counter" "$item" "$reset"
    ((file_counter++))
  done

  printf "%b\n" "$pipe"
}

# --------------------------------------
# Git file map from status
# --------------------------------------

git_file_map_from_status() {
  local staged_var="${1:-}"
  local unstaged_var="${2:-}"
  local untracked_var="${3:-}"

  file_counter=1
  git_file_map=()

  local git_root
  git_root=$(get_git_root) || {
    echo "⚠️ Not inside a Git repository."
    return 1
  }

  local -a staged_items unstaged_items untracked_items
  local allStaged allUnstaged allUntracked label file

  while IFS= read -r line; do
    allStaged="${line:0:1}"    # staged
    allUnstaged="${line:1:1}"  # unstaged
    allUntracked="${line:0:2}" # untracked
    file="${line:3}"           # file name

    [[ -z "$file" ]] && continue

    # --- Staged ---
    if [[ "$allStaged" != " " && "$allStaged" != "?" ]]; then
      case "$allStaged" in
        M) label="${green} modified:" ;;
        A) label="${green} new file:" ;;
        D) label="${red}  deleted:" ;;
        R) label="${green}  renamed:" ;;
        C) label="${green}   copied:" ;;
        *) label="${green}  changed:" ;;
      esac
      staged_items+=("$label $reset$file")
    fi

    # --- Unstaged ---
    if [[ "$allUnstaged" == "M" || "$allUnstaged" == "D" ]]; then
      case "$allUnstaged" in
        M) label="${orange} modified:" ;;
        D) label="${red}  deleted:" ;;
      esac
      unstaged_items+=("$label $reset$file")
    fi

    # --- Untracked ---
    if [[ "$allUntracked" == "??" ]]; then
      untracked_items+=("${cyan}untracked: ${reset}$file")
    fi
  done < <(git status --porcelain 2>/dev/null)

  # Staged
  for item in "${staged_items[@]}"; do
    local file=$(_extract_filename "$item")
    local abs_file="$git_root/$file"
    git_file_map[$file_counter]="$abs_file"
    ((file_counter++))
  done

  # Unstaged
  for item in "${unstaged_items[@]}"; do
    local file=$(_extract_filename "$item")
    local abs_file="$git_root/$file"
    git_file_map[$file_counter]="$abs_file"
    ((file_counter++))
  done

  # Untracked
  for item in "${untracked_items[@]}"; do
    local file=$(_extract_filename "$item")
    local abs_file="$git_root/$file"
    git_file_map[$file_counter]="$abs_file"
    ((file_counter++))
  done

  # Return arrays in a way that is compatible with both shells
  if [[ -n "$staged_var" ]]; then
    if [[ "$__SHELL_TYPE" == "bash" ]] && [[ "${BASH_VERSINFO[0]}" -ge 4 ]] && [[ "${BASH_VERSINFO[1]}" -ge 3 ]]; then
      # Bash 4.3+ supports nameref (more efficient)
      local -n _ref="$staged_var"
      _ref=("${staged_items[@]}")
    else
      # Fallback to eval (Zsh or old Bash)
      eval "$staged_var=(\"\${staged_items[@]}\")"
    fi
  fi

  if [[ -n "$unstaged_var" ]]; then
    if [[ "$__SHELL_TYPE" == "bash" ]] && [[ "${BASH_VERSINFO[0]}" -ge 4 ]] && [[ "${BASH_VERSINFO[1]}" -ge 3 ]]; then
      local -n _ref="$unstaged_var"
      _ref=("${unstaged_items[@]}")
    else
      eval "$unstaged_var=(\"\${unstaged_items[@]}\")"
    fi
  fi

  if [[ -n "$untracked_var" ]]; then
    if [[ "$__SHELL_TYPE" == "bash" ]] && [[ "${BASH_VERSINFO[0]}" -ge 4 ]] && [[ "${BASH_VERSINFO[1]}" -ge 3 ]]; then
      local -n _ref="$untracked_var"
      _ref=("${untracked_items[@]}")
    else
      eval "$untracked_var=(\"\${untracked_items[@]}\")"
    fi
  fi
}

# --------------------------------------
# Extract filename from colored string
# --------------------------------------

_extract_filename() {
  local colored_string="$1"
  echo "${colored_string##*$reset}"
}