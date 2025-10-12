# ===== GIT =====
alias gsb='git status -sb'
alias gc='git commit -v'
alias gco='git checkout'
alias gpl='git pull --rebase'
alias gps='git push'
alias gl='git log --graph \
  --abbrev-commit \
  --decorate \
  --date="format-local:%Y-%m-%d" \
  --pretty=format:"%C(bold blue)%h%C(reset)%C(auto)%d%C(reset) %C(white)%s%C(reset) %C(dim white)by%C(reset) %C(bold white)%an%C(reset) %C(dim white)on%C(reset) %C(bold green)%cr%C(reset)%n"
'
alias gs='git_status'
alias ga='git_add'
alias gd='git_diff'
alias grs='git_reset'

# ===== SYSTEM =====
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -lah'
alias la='ls -A'
alias reload='source ~/.zshrc'