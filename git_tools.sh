# ===== GIT ADVANCED =====

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

  print_git_section "$git_staged_color"    "Changes to be committed:"        "$max_len" "$padding" "${GIT_STAGED[@]}"
  print_git_section "$git_unstaged_color"  "Changes not staged for commit:"  "$max_len" "$padding" "${GIT_UNSTAGED[@]}"
  print_git_section "$git_untracked_color" "Untracked files:"                "$max_len" "$padding" "${GIT_UNTRACKED[@]}"
}

# --------------------------------
# Git add
# --------------------------------

git_add() {
  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: ga <number(s) or interval(s)>"
    echo "Ex: ga 1 3 5-7"
    return 1
  fi

  if [[ ${#git_file_map[@]} -eq 0 ]]; then
    git_file_map_from_status
  fi

  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "❌ Not a Git repository"
    return 1
  }

  local -a indexes=() files_to_add=()

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
    if [[ -z "${git_file_map[$i]}" ]]; then
      echo "⚠️ Number out of range: $i (1-${#git_file_map[@]})"
      continue
    fi
    files_to_add+=("${git_file_map[$i]}")
  done

  if [[ ${#files_to_add[@]} -eq 0 ]]; then
    echo "⚠️ No valid files selected."
    return 1
  fi

  if (cd "$root" && git add -- "${files_to_add[@]}" 2>/dev/null); then
    git_status
  else
    echo "❌ Failed to add files."
    return 1
  fi
}

# --------------------------------
# Git diff
# --------------------------------

git_diff() {
  local num="$1"
  local git_root=$(get_git_root)

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
  cd "$git_root" && git diff --color=always -- "$file" | less -R
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
  local git_root=$(get_git_root)

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

  if (cd "$git_root" && git reset HEAD -- "${files_to_reset[@]}" >/dev/null 2>&1); then
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
# Relative path
# --------------------------------------

get_relative_path() {
  local file="$1"
  local git_root="$(get_git_root)"

  python3 -c "import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" \
    "$git_root/$file" "$PWD"
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
  shift 4
  local items=("$@")
  local pipe="${color}║${reset}"

  [[ ${#items[@]} -eq 0 ]] && return

  local buffer=""
  buffer+="${color}⦿ - ${title}${reset}\n"
  buffer+="${pipe}\n"

  local item type file display_file index_width space_padding

  local git_root=$(get_git_root)

  for item in "${items[@]}"; do
    type="${item%%|*}"
    file="${item#*|}"

    display_file="${file#$git_root/}"
    if [[ "$PWD" != "$git_root" ]]; then
      local rel_from_pwd="${PWD#$git_root/}"
      if [[ -n "$rel_from_pwd" ]]; then
        local ups=""
        IFS='/' read -rA dirs <<< "$rel_from_pwd"
        for _ in "${dirs[@]}"; do
          ups="../$ups"
        done
        display_file="${ups}${display_file}"
      fi
    fi

    index_width=${#file_counter}
    space_padding=$((bracket_width - index_width - 2))

    buffer+=$(printf "%b\t%*s%b[%b%d%b] %s%-*s%s : %s%b\n" \
      "$pipe" "$space_padding" "" "$white" "$reset" "$file_counter" "$white" \
      "$color" "$max_len" "$type" "$reset" "$display_file" "$reset")
    buffer+="\n"

    ((file_counter++))
  done

  buffer+="${pipe}\n"

  printf "%b" "$buffer"
}

# --------------------------------------
# Git file map from status
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