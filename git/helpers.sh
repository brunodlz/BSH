# --------------------------------------
# Git root
# --------------------------------------

get_git_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

get_current_branch() {
  git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

# ---------------------------------------
# Execute git commands at repository root
# ---------------------------------------

execute_command() {
  local root
  root=$(get_git_root)

  if [[ -z "$root" ]]; then
    echo "❌ Not a Git repository"
    return 1
  fi

  # Se o primeiro argumento já for "git", remove-o para não duplicar (ex: "git add" vira "add")
  if [[ "$1" == "git" ]]; then
    shift
  fi

  # Executa o comando git no diretório raiz do repositório sem mudar o PWD do terminal
  command git -C "$root" "$@"
}
