# 🧠 BSH — Bruno Shell Toolkit

A lightweight shell environment that enhances Git, aliases, and developer productivity.

## 🛠 Installation

```bash
git clone https://github.com/brunodlz/BSH.git ~/.bsh
~/.bsh/install.sh
source ~/.bashrc # or source ~/.zshrc
```

The install script automatically appends the following line to your .bashrc or .zshrc:
```bash
[ -s "$HOME/.bsh/load.sh" ] && source "$HOME/.bsh/load.sh"
```
