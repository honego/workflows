<div align="center">
  <img src="https://fastly.jsdelivr.net/gh/jglovier/dotfiles-logo@main/dotfiles-logo.png" alt="Logo" width="400" />
</div>

## .bashrc

Description: This file is used to enhance the default .bashrc, add custom parameters.

```shell
cp ~/.bashrc{,.bak}
```

Debian Series

```
curl -Ls https://github.com/honeok/config/raw/master/dotfiles/.debian_bashrc -o ~/.bashrc
```

```
. ~/.bashrc
```

## 99-honeok.sh

Description: This script is used custom motd showing hostname ip address disk usage and system uptime.

```shell
curl -Ls https://github.com/honeok/config/raw/master/dotfiles/99-honeok.sh -o /etc/profile.d/99-honeok.sh
chmod +x /etc/profile.d/99-honeok.sh
```
