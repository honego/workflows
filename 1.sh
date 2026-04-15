#!/bin/bash

print_title() {
    local LC_CTYPE title line_width title_width pad_width left_width right_width index current_char current_code dash_buffer

    LC_CTYPE=C.UTF-8 # UTF-8 按字符截取
    title="$*"       # 接收函数全部参数作为标题文本
    line_width=60    # 基准宽度
    title_width=0    # 初始化标题显示宽度
    pad_width=0      # 初始化左右两侧 '-' 的总宽度
    left_width=0     # 初始化左侧 '-' 数量
    right_width=0    # 初始化右侧 '-' 数量
    index=0          # 初始化循环下标
    current_char=''  # 初始化当前字符
    current_code=0   # 初始化当前字符编码值
    dash_buffer=''   # 初始化横杠缓冲区

    # 计算标题显示宽度
    for ((index = 0; index < ${#title}; index++)); do
        current_char="${title:index:1}"
        printf -v current_code '%d' "'$current_char"

        if ((current_code >= 0 && current_code <= 127)); then
            ((title_width += 1))
        else
            ((title_width += 2))
        fi
    done

    # 标题左右各预留 1 个空格
    if ((title_width + 2 > line_width)); then
        printf '%s\n' "$title"
        return
    fi

    # 按 60 个 '-' 的基准宽度计算左右两边需要补多少个 '-'
    pad_width=$((line_width - title_width - 2))
    left_width=$((pad_width / 2))
    right_width=$((pad_width - left_width))

    # 输出左侧 '-' 空格 标题 空格
    printf -v dash_buffer '%*s' "$left_width" ''
    printf '%s %s ' "${dash_buffer// /-}" "$title"

    # 输出右侧 '-' 并换行
    printf -v dash_buffer '%*s' "$right_width" ''
    printf '%s\n' "${dash_buffer// /-}"
}

print_title 基础信息查询
print_title Basic System Information
