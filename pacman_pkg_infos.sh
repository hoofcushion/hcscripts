#!/bin/bash

# 默认排序字段和顺序
SORT_FIELD="date"
REVERSE=false

# 显示用法信息
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Display explicitly installed packages with formatted information.

OPTIONS:
    -s, --sort FIELD    Sort by 'date' or 'name' (default: date)
    -r, --reverse       Reverse sort order
    -h, --help          Show this help message

EXAMPLES:
    $(basename "$0")                    # Sort by date (newest first)
    $(basename "$0") -s name            # Sort by package name
    $(basename "$0") -s date -r         # Sort by date (oldest first)
    $(basename "$0") -s name -r         # Sort by name (reverse alphabetical)
EOF
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--sort)
                case "$2" in
                    date|name)
                        SORT_FIELD="$2"
                        shift 2
                        ;;
                    *)
                        echo "Error: Invalid sort field '$2'. Use 'date' or 'name'." >&2
                        exit 1
                        ;;
                esac
                ;;
            -r|--reverse)
                REVERSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                show_usage
                exit 1
                ;;
        esac
    done
}

# 获取显式安装的包（排除包组）
get_explicit_packages() {
    local explicit_packages=()
    local group_packages=()
    
    # 使用数组存储包名
    mapfile -t explicit_packages < <(pacman -Qqe)
    mapfile -t group_packages < <(pacman -Qqg | awk '{print $2}')
    
    # 使用关联数组进行快速查找
    local -A group_map
    local pkg
    for pkg in "${group_packages[@]}"; do
        group_map["$pkg"]=1
    done
    
    # 过滤出显式安装的包
    local result=()
    for pkg in "${explicit_packages[@]}"; do
        [[ -z ${group_map["$pkg"]} ]] && result+=("$pkg")
    done
    
    printf '%s\n' "${result[@]}"
}

# 格式化单个包的信息
format_single_package() {
    local package="$1"
    LC_ALL=C pacman -Qi --quiet "$package" | awk -F': ' '
    function format_date(date_str) {
        cmd = "date -d \"" date_str "\" \"+%Y-%m-%d %H:%M:%S\" 2>/dev/null"
        cmd | getline formatted
        close(cmd)
        return formatted ? formatted : date_str
    }
    
    /^Name/ { name = $2 }
    /^Install Date/ { installdate = format_date($2) }
    /^Description/ { description = $2 }
    /^$/ {
        if (name && installdate && description) {
            printf "%-20s | %-26s | %s\n", installdate, name, description
        }
        name = ""; installdate = ""; description = ""
    }
    END {
        if (name && installdate && description) {
            printf "%-20s | %-26s | %s\n", installdate, name, description
        }
    }'
}

# 批量格式化包信息
format_packages() {
    local packages=("$@")
    local pkg
    for pkg in "${packages[@]}"; do
        format_single_package "$pkg"
    done
}

# 排序函数
sort_packages() {
    local sort_field="$1"
    local reverse="$2"
    local sort_opts=()
    
    case "$sort_field" in
        date)
            sort_opts=(-t '|' -k1,1)
            ;;
        name)
            sort_opts=(-t '|' -k2,2)
            ;;
    esac
    
    if [[ "$reverse" == true ]]; then
        sort_opts+=(-r)
    fi
    
    sort "${sort_opts[@]}"
}

# 主函数
main() {
    parse_arguments "$@"
    
    echo "Install Date         | Package Name               | Description"
    echo "---------------------|----------------------------|----------------------------------------"
    
    # 读取包列表到数组
    local packages=()
    mapfile -t packages < <(get_explicit_packages)
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "No explicitly installed packages found."
        return
    fi
    
    # 分批处理避免参数过长
    local all_output=()
    local i
    for ((i=0; i<${#packages[@]}; i+=50)); do
        local group=("${packages[@]:i:50}")
        local output
        output=$(format_packages "${group[@]}")
        all_output+=("$output")
    done
    
    # 合并所有输出并排序
    printf '%s\n' "${all_output[@]}" | sort_packages "$SORT_FIELD" "$REVERSE"
}

# 如果脚本被直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
