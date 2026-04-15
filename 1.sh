#!/bin/bash

print_title() {
    local LC_COLLATE title total_width title_width content_width remaining_width left_dash_width right_dash_width index current_char dash_buffer

    LC_COLLATE=C
    title="$*"         # 接收函数全部参数作为标题文本
    total_width=60     # 整行总宽度为 60
    title_width=0      # 初始化标题显示宽度计数器
    content_width=0    # 初始化标题内容总宽度
    remaining_width=0  # 初始化剩余宽度
    left_dash_width=0  # 初始化左侧横杠数量
    right_dash_width=0 # 初始化右侧横杠数量
    index=0            # 初始化循环变量
    current_char=''    # 初始化当前字符变量
    dash_buffer=''     # 初始化横杠缓冲区

    # 计算标题显示宽度
    for ((index = 0; index < ${#title}; index++)); do
        current_char="${title:index:1}"
        case "$current_char" in
        [!-~] | ' ')
            ((title_width += 1))
            ;;
        *)
            ((title_width += 2))
            ;;
        esac
    done

    # 标题左右各补 1 个空格
    content_width=$((title_width + 2))

    # 如果标题本身已经超过总宽度则直接输出
    if ((content_width >= total_width)); then
        printf '%s\n' "$title"
        return
    fi

    # 计算左右两边需要补多少个横杠
    remaining_width=$((total_width - content_width))
    left_dash_width=$((remaining_width / 2))
    right_dash_width=$((remaining_width - left_dash_width))

    # 生成并输出左侧横杠
    printf -v dash_buffer '%*s' "$left_dash_width" ''
    printf '%s %s ' "${dash_buffer// /-}" "$title"

    # 生成并输出右侧横杠
    printf -v dash_buffer '%*s' "$right_dash_width" ''
    printf '%s\n' "${dash_buffer// /-}"
}

print_title 基础信息查询
print_title Basic System Information
