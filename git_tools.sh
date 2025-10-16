# ===== GIT ADVANCED =====

# --------------------------------
# Regular Colors
# --------------------------------
green=$'\033[32m'
red=$'\033[31m'
orange=$'\033[38;5;214m'
cyan=$'\033[36m'
gray=$'\033[1;90m'
white=$'\033[37m'

# --------------------------------
# Reset
# --------------------------------
reset=$'\033[0m'

# --------------------------------
# Text Styles
# --------------------------------
bold=$'\033[1m'

# --------------------------------
# Git Status Colors
# --------------------------------
git_staged_color=$green
git_unstaged_color=$orange
git_untracked_color=$cyan

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
  print_branch_header
  git_file_map_from_status

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

  file_counter=1

  print_git_section "$git_staged_color"    "Changes to be committed:"        "$max_len" "$padding" "staged"    "${GIT_STAGED[@]}"
  print_git_section "$git_unstaged_color"  "Changes not staged for commit:"  "$max_len" "$padding" "unstaged"  "${GIT_UNSTAGED[@]}"
  print_git_section "$git_untracked_color" "Untracked files:"                "$max_len" "$padding" "untracked" "${GIT_UNTRACKED[@]}"
}

# --------------------------------
# Git add
# --------------------------------

git_add() {
  local root files=() indexes=()
  local staged_files unstaged_files untracked_files renamed_files

  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "❌ Not a Git repository"
    return 1
  }

  local status_output
  status_output=$(git -C "$root" status --porcelain 2>/dev/null)

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local file="${line:3}"
    [[ -n "$file" ]] && files+=("$file")
  done <<< "$status_output"

  if [[ "$__SHELL_TYPE" == "zsh" ]]; then
    files=(${(u)files})
  else
    files=($(printf '%s\n' "${files[@]}" | sort -u))
  fi

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
  if [[ "$__SHELL_TYPE" == "zsh" ]]; then
    indexes=(${(nu)indexes})
  else
    indexes=($(printf '%s\n' "${indexes[@]}" | sort -nu))
  fi

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

  local file="${git_file_map[$num]}"
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

  if [[ "$__SHELL_TYPE" == "zsh" ]]; then
    indexes=(${(nu)indexes})
  else
    indexes=($(printf '%s\n' "${indexes[@]}" | sort -nu))
  fi

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

  if git reset HEAD -- "${files_to_reset[@]}" >/dev/null 2>&1; then
    for file in "${files_to_reset[@]}"; do
      echo "🧹 Removed from stage: $file"
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
# Git root (cached)
# --------------------------------------

get_git_root() {
  if [[ -z "$__GIT_ROOT_CACHE" ]]; then
    __GIT_ROOT_CACHE=$(git rev-parse --show-toplevel 2>/dev/null)
  fi
  echo "$__GIT_ROOT_CACHE"
}

get_current_branch() {
  echo "$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)"
}

# --------------------------------------
# Relative path (nativo do shell)
# --------------------------------------

get_relative_path() {
  local target="$1"
  local base="${2:-$PWD}"

  if [[ "$target" == "$base"* ]]; then
    echo "${target#$base/}"
  else
    echo "$target"
  fi
}

# --------------------------------------
# Print
# --------------------------------------

print_branch_header() {
  local current_branch

  # Get current branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  # Current branch
  printf "%b⦿ - On branch: %b%b%s%b\n" "$white" "$reset" "$bold" "$current_branch" "$reset"
  printf "%b║%b\n" "$white" "$reset"
}

print_git_section() {
  local color="$1"
  local title="$2"
  local max_len="$3"
  local bracket_width="$4"
  local section_type="$5"
  shift 5
  local items=("$@")
  local pipe="${color}║${reset}"

  [[ ${#items[@]} -eq 0 ]] && return

  printf "${color}⦿ - %s\n${reset}" "$title"
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
    printf "%b|%b%d%b| " "$white" "$reset" "$file_counter" "$white"
    printf "%s%-*s%s : %s%b\n" "$color" "$max_len" "$type" "$reset" "$file" "$reset"

    ((file_counter++))
  done

  printf "%b\n" "$pipe"
}

# --------------------------------------
# Git file map from status (OTIMIZADO)
# --------------------------------------

git_file_map_from_status() {
  local staged_items=()
  local unstaged_items=()
  local untracked_items=()

  git_file_map=()

  local git_root
  git_root=$(get_git_root) || {
    echo "⚠️ Not inside a Git repository."
    return 1
  }

  local label file
  local staged unstaged

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    staged="${line:0:1}"
    unstaged="${line:1:1}"
    file="${line:3}"

    [[ -z "$file" ]] && continue

    # Staged
    if [[ "$staged" != " " && "$staged" != "?" ]]; then
      case "$staged" in
        M) label="modified" ;;
        A) label="new file" ;;
        D) label="deleted" ;;
        R) label="renamed" ;;
        C) label="copied" ;;
        *) label="changed" ;;
      esac
      staged_items+=("$label|$file")
    fi

    # Unstaged
    if [[ "$unstaged" == "M" || "$unstaged" == "D" ]]; then
      case "$unstaged" in
        M) label="modified" ;;
        D) label="deleted" ;;
      esac
      unstaged_items+=("$label|$file")
    fi

    # Untracked
    if [[ "$staged$unstaged" == "??" ]]; then
      untracked_items+=("untracked|$file")
    fi
  done < <(git -C "$git_root" status --porcelain 2>/dev/null)

  file_counter=1
  local item

  for item in "${staged_items[@]}" "${unstaged_items[@]}" "${untracked_items[@]}"; do
    git_file_map[$file_counter]="${item#*|}"
    ((file_counter++))
  done

  GIT_STAGED=("${staged_items[@]}")
  GIT_UNSTAGED=("${unstaged_items[@]}")
  GIT_UNTRACKED=("${untracked_items[@]}")
}