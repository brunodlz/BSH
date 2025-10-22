git_checkout() {
  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: gco <number(s) or interval(s), '.' or branch>"
    echo "Ex: gco 1 3 5-7"
    return 1
  fi

  if [[ "$1" == "." ]]; then
    echo "♻️ Restoring all unstaged files..."
    git checkout -- .
    return $?
  fi

  local all_numeric=true
  for arg in "$@"; do
    if [[ ! "$arg" =~ ^[0-9]+(-[0-9]+)?$ ]]; then
      all_numeric=false
      break
    fi
  done

  if ! $all_numeric; then
    git checkout "$@"
    return $?
  fi

  if [[ ${#git_file_map[@]} -eq 0 ]]; then
    git_file_map_from_status
  fi

  local root
  root=$(get_git_root)
  if [[ -z "$root" ]]; then
    echo "❌ Not a Git repository"
    return 1
  fi

  local -a indexes=() files_to_checkout=()

  for arg in "$@"; do
    if [[ "$arg" == *-* ]]; then
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
    files_to_checkout+=("${git_file_map[$i]}")
  done

  if [[ ${#files_to_checkout[@]} -eq 0 ]]; then
    echo "⚠️ No valid files selected."
    return 1
  fi

  if execute_command git checkout -- "${files_to_checkout[@]}"; then
    for file in "${files_to_checkout[@]}"; do
      echo "♻️ Checked out: $file"
    done
  else
    echo "❌ Failed to checkout files."
    return 1
  fi
}