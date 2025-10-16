comm -23 <(pacman -Qqe | sort) <(pacman -Qqg | awk '{print $2}' | sort -u) \
 | LC_ALL=C xargs -r pacman -Qi --quiet \
 | awk -F': ' '/^Name/{name=$2} /^Description/{print name ": " $2}'
