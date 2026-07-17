# shellcheck shell=bash
# shellcheck disable=SC1090,SC1091
# Copyright (c) 2025-2026 honeok <i@honeok.com>
# SPDX-License-Identifier: MIT

# Based from: https://sources.debian.org/src/bash/*/debian/skel.bashrc

# 非交互模式下跳过执行
case $- in
*i*) ;;
*) return ;;
esac

# 设置当前 Shell 及子进程的 UTF-8 语言环境
export LANG=en_US.UTF-8

# Debian / Ubuntu 软件包配置始终使用非交互模式
export DEBIAN_FRONTEND=noninteractive

# 配置命令历史记录
HISTCONTROL=ignoreboth  # 忽略连续重复命令和以空格开头的命令
HISTSIZE=500            # 当前终端会话内存中保留的最大命令数量
HISTFILESIZE=1000       # 历史记录文件 ~/.bash_history 中保留的最大命令数量
HISTTIMEFORMAT='%F %T ' # 为历史记录显示添加时间戳

shopt -s histappend   # Shell 退出时将本次命令历史追加到历史文件而不是覆盖
shopt -s checkwinsize # 执行外部命令后自动更新终端窗口尺寸
shopt -s dirspell     # 补全目录名时尝试纠正轻微拼写错误

# 启用 less 输入预处理 支持查看压缩包和部分非文本文件
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh /usr/bin/lesspipe)"

# 读取 chroot 环境名称供命令提示符显示
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot="$(< /etc/debian_chroot)"
fi

# 设置命令提示符
PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '

# 针对 xterm 和 rxvt 终端设置窗口标题
case "$TERM" in
xterm* | rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
esac

# 加载 ls 颜色配置
if [ -x /usr/bin/dircolors ]; then
    if [ -r "$HOME/.dircolors" ]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
fi

# 定义 ls 彩色输出别名
alias ls='ls --color=auto'
alias l='ls -CF'
alias ll='ls -Alh --time-style=long-iso'
alias la='ls -A'

# 定义 grep 彩色输出别名
alias grep='grep --color=auto'
alias fgrep='grep -F'
alias egrep='grep -E'

# 加载用户自定义别名文件
if [ -f "$HOME/.bash_aliases" ]; then
    . "$HOME/.bash_aliases"
fi

# 启用命令自动补全
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# 防止误操作的别名
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'

# 定义目录导航快捷别名
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
