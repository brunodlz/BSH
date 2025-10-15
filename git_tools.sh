# ===== GIT ADVANCED =====

# --------------------------------
# Colors
# --------------------------------

green=$'\033[32m'
red=$'\033[31m'
orange=$'\033[38;5;214m'
cyan=$'\033[36m'
gray=$'\033[1;90m'
white=$'\033[37m'
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
  git_file_map_from_status

  file_counter=1

  local all_items=("${GIT_STAGED[@]}" "${GIT_UNSTAGED[@]}" "${GIT_UNTRACKED[@]}")
  local max_len=0
  local item type
  for item in "${all_items[@]}"; do
      type="${item%%|*}"
      (( ${#type} > max_len )) && max_len=${#type}
  done

  local total_files=$(( ${#GIT_STAGED[@]} + ${#GIT_UNSTAGED[@]} + ${#GIT_UNTRACKED[@]} ))
  local last_index=$((file_counter + total_files - 1))
  local max_index_width=${#last_index}
  local padding=$((max_index_width + 2))

  print_git_section "$green"  "Changes to be committed:"        "$max_len" "$padding" "staged"    "${GIT_STAGED[@]}"
  print_git_section "$orange" "Changes not staged for commit:"  "$max_len" "$padding" "unstaged"  "${GIT_UNSTAGED[@]}"
  print_git_section "$cyan"   "Untracked files:"                "$max_len" "$padding" "untracked" "${GIT_UNTRACKED[@]}"
}

# --------------------------------
# Git add
# --------------------------------

git_add() {
  local root files=() indexes=()
  local staged_files unstaged_files untracked_files renamed_files

  # Set the root directory of the git repository
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "❌ Not a Git repository"
    return 1
  }

  # Get all staged and unstaged files
  staged_files=("${(@f)$(git -C "$root" diff --cached --name-only | sed '/^$/d' | tr -d '\r')}")
  unstaged_files=("${(@f)$(git -C "$root" diff --name-only | sed '/^$/d' | tr -d '\r')}")
  untracked_files=("${(@f)$(git -C "$root" ls-files --others --exclude-standard | tr -d '\r')}")
  renamed_files=("${(@f)$(git -C "$root" diff --name-status | awk '/^R/{ print $3 }' | tr -d '\r')}")

  # Combine and remove duplicates
  for f in "${staged_files[@]}" "${unstaged_files[@]}" "${untracked_files[@]}" "${renamed_files[@]}"; do
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
      local file="${files[$i]}"
      (cd "$root" && git add -- "$file" 2>/dev/null)
    else
      echo "⚠️ Invalid number: $i (range: 1-${#files[@]})"
    fi
  done

  git_status
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
    echo "‼️ Use: gr <numbers or ranges>"
    echo "Ex: gr 1 3 5-7"
    return 1
  fi

  if [[ ${#git_file_map[@]} -eq 0 ]]; then
    git_file_map_from_status
  fi

  local -a indexes=() files_to_reset=()

  for arg in "$@"; do
    if [[ "$arg" == *-* ]]; then
      local start end
      IFS='-' read -r start end <<< "$arg"
      if [[ ! "$start" =~ ^[0-9]+$ || ! "$end" =~ ^[0-9]+$ || $start -gt $end ]]; then
        echo "⚠️ Invalid interval: $arg"
        continue
      fi
      for ((i = start; i <= end; i++)); do
        indexes+=("$i")
      done
    else
      if [[ ! "$arg" =~ ^[0-9]+$ ]]; then
        echo "⚠️ Invalid number: $arg"
        continue
      fi
      indexes+=("$arg")
    fi
  done

  indexes=($(printf '%s\n' "${indexes[@]}" | sort -nu))

  for i in "${indexes[@]}"; do
    if [[ -z "${git_file_map[$i]}" ]]; then
      echo "⚠️ Number out of range: $i (1-${#git_file_map[@]})"
      continue
    fi
    files_to_reset+=("${git_file_map[$i]}")
  done

  if [[ ${#files_to_reset[@]} -eq 0 ]]; then
    echo "⚠️ No valid files selected."
    return 1
  fi

  if git reset HEAD -- "${files_to_reset[@]}" >/dev/null; then
    for file in "${files_to_reset[@]}"; do
      rel_path=$(realpath --relative-to="$PWD" "$file" 2>/dev/null || echo "$file")
      echo "🧹 Removed from stage: $rel_path"
    done
  else
    echo "❌ Failed to reset files."
    return 1
  fi

  git_status
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
  local max_len="$3"
  local bracket_width="$4"
  local section_type="$5"  # staged, unstaged, untracked
  shift 5
  local items=("$@")
  local pipe="${color}|${reset}"

  [[ ${#items[@]} -eq 0 ]] && return

  printf "%b\n" "$white$pipe$reset"
  printf "%b ➤ %s\n" "$pipe" "$title"
  printf "%b\n" "$pipe"

  for item in "${items[@]}"; do
    local type="${item%%|*}"
    local file="${item#*|}"
    local type_color="$reset"

    case "$type" in
        modified)  type_color="$green" ;;
        "new file") type_color="$green" ;;
        deleted)   type_color="$red" ;;
        renamed)   type_color="$cyan" ;;
        copied)    type_color="$cyan" ;;
        untracked) type_color="$cyan" ;;
    esac

    local index_width=${#file_counter}
    local space_padding=$((bracket_width - index_width - 2))

    printf "%b\t%*s" "$pipe" "$space_padding" ""
    printf "%b[%b%d%b] " "$white" "$reset" "$file_counter" "$white"
    printf "%s%-*s%s: %s%b\n" "$color" "$max_len" "$type" "$reset" "$file" "$reset"

    ((file_counter++))
  done

  printf "%b\n" "$pipe"
}

# --------------------------------------
# Git file map from status
# --------------------------------------

git_file_map_from_status() {
  GIT_STAGED=()
  GIT_UNSTAGED=()
  GIT_UNTRACKED=()

  file_counter=1
  git_file_map=()

  local git_root
  git_root=$(get_git_root) || {
    echo "⚠️ Not inside a Git repository."
    return 1
  }

  local -a staged_items unstaged_items untracked_items
  local allStaged allUnstaged allUntracked label file absolute_path relative_path

  while IFS= read -r line; do
    allStaged="${line:0:1}"    # staged
    allUnstaged="${line:1:1}"  # unstaged
    allUntracked="${line:0:2}" # untracked
    file="${line:3}"           # filename

    [[ -z "$file" ]] && continue

    absolute_path="$git_root/$file"

    if command -v realpath &>/dev/null; then
      relative_path=$(python3 -c "import os; print(os.path.relpath('$absolute_path', '$PWD'))")
    else
      relative_path="$file"
    fi

    # --- Staged ---
    if [[ "$allStaged" != " " && "$allStaged" != "?" ]]; then
      case "$allStaged" in
        M) label="modified" ;;
        A) label="new file" ;;
        D) label="deleted" ;;
        R) label="renamed" ;;
        C) label="copied" ;;
        *) label="changed" ;;
      esac
      staged_items+=("$label|$relative_path")
    fi

    # --- Unstaged ---
    if [[ "$allUnstaged" == "M" || "$allUnstaged" == "D" ]]; then
      case "$allUnstaged" in
        M) label="modified" ;;
        D) label="deleted" ;;
      esac
      unstaged_items+=("$label|$relative_path")
    fi

    # --- Untracked ---
    if [[ "$allUntracked" == "??" ]]; then
      untracked_items+=("untracked|$relative_path")
    fi
  done < <(git -C "$git_root" status --porcelain 2>/dev/null)

  local item file_path

  # Staged + Unstaged + Untracked
  for item in "${staged_items[@]}" "${unstaged_items[@]}" "${untracked_items[@]}"; do
    file_path="${item#*|}"
    repo_relative_path=$(python3 -c "import os; print(os.path.relpath('$git_root/$file_path', '$git_root'))")
    git_file_map[$file_counter]="$repo_relative_path"
    ((file_counter++))
  done

  GIT_STAGED=("${staged_items[@]}")
  GIT_UNSTAGED=("${unstaged_items[@]}")
  GIT_UNTRACKED=("${untracked_items[@]}")
}

# --------------------------------------
# Extract filename from colored string
# --------------------------------------

_extract_filename() {
  local colored_string="$1"
  echo "${colored_string#*$reset}"
}