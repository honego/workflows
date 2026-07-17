# shellcheck shell=bash
# shellcheck disable=SC1090,SC1091
# Copyright (c) 2025-2026 honeok <i@honeok.com>
# SPDX-License-Identifier: MIT

# References:
# https://sources.debian.org/src/bash/*/debian/skel.bashrc

# 非交互模式下跳过执行
[ -z "$PS1" ] && return

# 设置系统 utf-8 语言环境
export LANG=en_US.UTF-8

# 环境变量用于在 debian 或 ubuntu 操作系统中设置非交互式 (noninteractive) 安装模式
export DEBIAN_FRONTEND=noninteractive

HISTCONTROL=ignoreboth  # 忽略连续重复命令和以空格开头的命令
HISTSIZE=500            # 当前终端会话内存中保留的最大命令数量
HISTFILESIZE=1000       # 历史记录文件 ~/.bash_history 中保留的最大命令数量
HISTTIMEFORMAT='%F %T ' # 为历史记录显示添加时间戳

shopt -s histappend   # Shell 退出时将本次命令历史追加到历史文件而不是覆盖
shopt -s dirspell     # 补全目录名时尝试纠正轻微拼写错误
shopt -s checkwinsize # 执行外部命令后自动更新终端窗口尺寸

# 启用 less 输入预处理, 支持查看压缩包和部分非文本文件
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh /usr/bin/lesspipe)"

# 设置用于标识当前 chroot 环境的变量
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
	debian_chroot="$(cat /etc/debian_chroot)"
fi

# 启用彩色提示符 针对 xterm-color 终端或 256 色终端
case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

# 强制启用彩色提示符 默认禁用, 如启用需取消注释
# force_color_prompt=yes

# 检查终端是否支持彩色提示符
if [ -n "$force_color_prompt" ]; then
	if [ -x /usr/bin/tput ] && tput setaf >/dev/null 2>&1; then
		color_prompt=yes
	else
		color_prompt=
	fi
fi

# 设置提示符格式 彩色或无色 包含chroot信息
if [ "$color_prompt" = yes ]; then
	PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
	PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# 设置终端标题为 user@host:dir 针对 xterm / rxvt 终端
case "$TERM" in
xterm* | rxvt*)
	PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
	;;
*)
	:
	;;
esac

# 自定义 root 提示符和文件权限掩码 默认由 /etc/profile 设置
# PS1='${debian_chroot:+($debian_chroot)}\h:\w\$ '
# umask 022

# You may uncomment the following lines if you want `ls' to be colorized:

# 启用 ls 的颜色支持, 并添加实用的别名
if [ -x /usr/bin/dircolors ]; then
	# 加载用户或系统默认颜色配置
	if [ -r ~/.dircolors ]; then
		eval "$(dircolors -b ~/.dircolors)"
	else
		eval "$(dircolors -b)"
	fi
	alias ls='ls --color=auto' # 定义 ls 彩色输出别名
	alias dir='dir --color=auto'
	alias vdir='vdir --color=auto'

	# 定义 grep 彩色输出别名
	alias grep='grep --color=auto'
	alias fgrep='grep -F --color=auto'
	alias egrep='grep -E --color=auto'
fi

alias l='ls -AC'
alias ll='ls -Al --time-style=long-iso'
alias la='ls -A'

# 防止误操作的别名
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'

# 加载用户自定义别名文件
if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

# 启用命令自动补全
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
	. /etc/bash_completion
elif [ -f /usr/share/bash-completion/bash_completion ] && ! shopt -oq posix; then
	. /usr/share/bash-completion/bash_completion
fi

# 定义目录导航快捷别名
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
