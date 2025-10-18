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