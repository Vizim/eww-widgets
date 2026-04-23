#!/usr/bin/env bash
# Delta-based CPU% from /proc/stat — no subprocesses, no sleep.
# eww calls this every 3s; the previous snapshot is cached between calls.
PREV="$HOME/.cache/eww-cpu-prev.txt"

read -r _ u n s id iow irq sir stl _ < /proc/stat

cur_total=$(( u + n + s + id + iow + irq + sir + stl ))
cur_idle=$id

if [[ -f "$PREV" ]]; then
  read -r p_u p_n p_s p_id p_iow p_irq p_sir p_stl < "$PREV"
  p_total=$(( p_u + p_n + p_s + p_id + p_iow + p_irq + p_sir + p_stl ))
  delta_total=$(( cur_total - p_total ))
  delta_idle=$(( cur_idle  - p_id ))
  if (( delta_total > 0 )); then
    echo $(( (delta_total - delta_idle) * 100 / delta_total ))
  else
    echo 0
  fi
else
  echo 0
fi

echo "$u $n $s $id $iow $irq $sir $stl" > "$PREV"
