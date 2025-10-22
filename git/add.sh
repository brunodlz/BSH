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

  if execute_command git add -- "${files_to_add[@]}"; then
    git_status
  else
    echo "❌ Failed to add files."
    return 1
  fi
}