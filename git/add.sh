git_add() {
  if [[ $# -eq 0 ]]; then
    echo "‼️ Use: ga <number(s) or interval(s)>"
    echo "Ex: ga 1 3 5-7"
    return 1
  fi

  # Garante que estamos dentro de um repositório git
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "❌ Not a Git repository"
    return 1
  }

  if [[ ${#git_file_map[@]} -eq 0 ]]; then
    git_file_map_from_status
  fi

  local -a raw_indexes=() files_to_add=()

  # 1. Parsing dos argumentos (números e intervalos)
  for arg in "$@"; do
    if [[ "$arg" == *-* ]]; then
      local start end
      IFS='-' read -r start end <<< "$arg"
      if [[ "$start" =~ ^[0-9]+$ ]] && [[ "$end" =~ ^[0-9]+$ ]]; then
        for ((i=start; i<=end; i++)); do
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

  if [[ ${#raw_indexes[@]} -eq 0 ]]; then
    echo "⚠️ No valid indexes provided."
    return 1
  fi

  # 2. Remoção de duplicatas e ordenação (compatível com Bash e Zsh)
  local -a indexes=($(printf '%s\n' "${raw_indexes[@]}" | sort -nu))

  # 3. Mapeamento dos arquivos selecionados
  for i in "${indexes[@]}"; do
    if [[ -n "${git_file_map[$i]}" ]]; then
      files_to_add+=("${git_file_map[$i]}")
    else
      echo "⚠️ Number out of range: $i (1-${#git_file_map[@]})"
    fi
  done

  if [[ ${#files_to_add[@]} -eq 0 ]]; then
    echo "⚠️ No valid files selected."
    return 1
  fi

  # 4. Execução e preservação do PWD do usuário
  local current_dir="$PWD"

  # Faz o add a partir da raiz do projeto para garantir caminhos relativos corretos
  if ( cd "$root" && execute_command git add -- "${files_to_add[@]}" ); then
    # Restaura o diretório antes de rodar o git_status
    cd "$current_dir" || return 1
    git_status
  else
    cd "$current_dir" || return 1
    echo "❌ Failed to add files."
    return 1
  fi
}
