git_reset() {
  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: gr <numbers or ranges>"
    echo "Ex: gr 1 3 5-7"
    return 1
  fi

  if [[ ${#git_file_map[@]} -eq 0 ]]; then
    git_file_map_from_status
  fi

  local -a raw_indexes=() files_to_reset=()

  for arg in "$@"; do
    if [[ "$arg" == *-* ]]; then
      local start end
      IFS='-' read -r start end <<< "$arg"
      if [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ && $start -le $end ]]; then
        for ((i = start; i <= end; i++)); do
          raw_indexes+=("$i")
        done
      else
        echo "⚠️ Invalid interval: $arg"
      fi
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
      raw_indexes+=("$arg")
    else
      echo "⚠️ Invalid number: $arg"
    fi
  done

  local -a indexes=($(printf '%s\n' "${raw_indexes[@]}" | sort -nu))

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

  if execute_command git reset HEAD -- "${files_to_reset[@]}" >/dev/null 2>&1; then
    for file in "${files_to_reset[@]}"; do
      echo "🧹 Removed from stage: $file"
    done
  else
    echo "❌ Failed to reset files."
    return 1
  fi

  git_status
}
