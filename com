#!/bin/sh
# $1 = number
# $2 = operator 
# $3 = number
# $1 or increase or decrease while $3 will remain the same
set -e # exit 1 if any error
ceil() {
  # ceiling $1, compare to $2; return 1 if not the same
  [ -z "${1##*.*}" -o ! -z "${2##*.*}" ] && {
    [ ! -z "${1##*.*}" -a ! -z "${2##*.*}" -a "$1" -eq "$2" ] 2>/dev/null && exit 0
    set -- "${1%.*}" "${2%.*}"
    set -- "$(($1+1))" "$2"
    [ "$1" -eq "$2" ] 2>/dev/null && {
      exit 0
    } || return 1
  } || return 1
} # ceiling
floor() {
  # floor $1. compare to $2; return 1 if not the same
  [ -z "${1##*.*}" -o ! -z "${2##*.*}" ] && {
    [ ! -z "${1##*.*}" -a ! -z "${2##*.*}" -a "$1" -eq "$2" ] 2>/dev/null && exit 0
    set -- "${1%.*}" "${2%.*}"
    set -- "$(($1-1))" "$2"
    [ "$1" -eq "$2" ] 2>/dev/null && {
      exit 0
    } || return 1
  } || return 1
} # floor
gt() {
  w1="${1%.*}"; w2="${2%.*}"
  d1="${1#*.}"; d2="${2#*.}"
  [ "$w1" -gt "$w2" ] && exit 0 # if whole number is greator no need to compare decimals
  # now compare $d1 to $d2
  # 0.10 > 0.01
  # 100 > 1
  until [ "${d1#0}" = "${d1}" ]; do
    d1="${d1#0}"; d2="${d2}0"
  done
  until [ "${d2#0}" = "${d2}" ]; do 
    d2="${d2#0}"; d1="${d1}0"
  done
  [ "$3" ] && {
    [ "$d1" -gt "$d2" -o "$d1" -eq "$d2" -a "$w1" -eq "$w2" ] && {
      exit 0
    } || return 1
  } || {
    [ "$d1" -gt "$d2" ] && { 
      exit 0
    } || return 1
  } # or equal to (-ge)
} # test if $1 is > $2
lt() { 
  w1="${1%.*}"; w2="${2%.*}"
  d1="${1#*.}"; d2="${2#*.}"
  [ "$w1" -lt "$w2" ] && exit 0
  until [ "${d1#0}" = "${d1}" ]; do
    d1="${d1#0}"; d2="${d2}0"
  done
  until [ "${d2#0}" = "${d2}" ]; do
    d2="${d2#0}"; d1="${d1}0"
  done
  [ "$3" ] && {
    [ "$d1" -lt "$d2" -o "$d1" -eq "$d2" -a "$w1" -eq "$w2" ] && {
      exit 0
    } || return 1
  } || {
    [ "$d1" -lt "$d2" ] && {
      exit 0
    } || return 1
  }
} # test if $1 is < $2
eq() { # use $3 for -ne
  w1="${1%.*}"; w2="${2%.*}"
  d1="${1#*.}"; d2="${2#*.}"
  until [ "${d1#0}" = "${d1}" ]; do
    d1="${d1#0}"; d2="${d2}0"
  done
  until [ "${d2#0}" = "${d2}" ]; do
    d2="${d2#0}"; d1="${d1}0"
  done
  [ "$3" ] && {
    [ "$w1" -ne "$w2" -a "$d1" -ne "$d2" ] && {
      exit 0
    } || return 1
  } || {
    [ "$w1" -eq "$w2" -a "$d1" -eq "$d2" ] && { 
      exit 0
    } || return 1
  }
}
n1="$1"; op="$2"; n2="$3"
case "$op" in
  '^~'|'~^'|'^='|'-cl') ceil "$n1" "$n2" || exit 1 ;;
  '~'|'≈'|'≅'|'-fl') floor "$n1" "$n2" || exit 1 ;;
  '>'|'-gt') gt "$n1" "$n2" || exit 1 ;;
  '<'|'-lt') lt "$n1" "$n2" || exit 1 ;;
  '-ge'|'>='|'=>') gt "$n1" "$n2" "-" || exit 1 ;;
  '-le'|'<='|'=<') lt "$n1" "$n2" "-" || exit 1 ;;
  # or equal to is set via $3
  '-eq'|'=='|'=') eq "$n1" "$n2" || exit 1 ;;
  '-ne'|'!=='|'!=') eq "$n1" "$n2" "-" || exit 1
  # -ne uses $3 with -eq
esac
exit 0 # exit 0 if done
