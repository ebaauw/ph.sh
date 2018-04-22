#!/bin/bash
#
# ph.sh
# Copyright © 2017, 2018 Erik Baauw. All rights reserved.
#
# Shell library for interacting with a Philips Hue or compatible bridge using
# the Philips Hue or compatible REST API.
# Currently tested on the following bridges:
# - Philips Hue v2 (square) bridge;
# - Philips Hue v1 (round) brudge;
# - dresden elektronik deCONZ REST API plugin.

# ===== CONFIGURATION ==========================================================

# Set default values.
: ${ph_verbose:=true}
: ${ph_debug:=false}

# ===== LIGHT STATE ============================================================

# Power-on color temperature.
ph_ct_poweron=366       # 2,732 Kelvin

# Light recipe color temperatures.
ph_ct_relaxed=447       # 2,237 Kelvin
ph_ct_read=346          # 2,890 Kelvin
ph_ct_concentrate=233   # 4,292 Kelvin
ph_ct_energize=156      # 6,410 Kelvin

# ===== UTILITY FUNCTIONS ======================================================

# Return quoted string from string.
# Usage: s=$(ph_quote string)
function ph_quote() {
  [[ "${1}" == '"'*'"' ]] && echo "${1}" || echo "\"${1}\""
}

# Remove quotes from string; return unquoted string from string.
# Usage: s=$(ph_unquote string)
function ph_unquote() {
  [[ "${1}" == '"'*'"' ]] && eval echo "${1}" || echo "${1}"
}

# Issue message on standard error
# Usage: _ph_msg severity [-n] [-s] message...
function _ph_msg() {
  local start="${_ph_host:-ph.sh}: ${1}${1:+: }"
  local nflag=
  shift
  if [ "${1}" == "-n" ] ; then
    nflag="-n"
    shift
  fi
  if [ "${1}" == "-s" ] ; then
    start=
    shift
  fi
  echo ${nflag} "${start}${*}" >&2
}

# Issue error message
# Usage: _ph_error [-n|-s] message...
function _ph_error() {
  _ph_msg error "${@}"
}

# Issue warning message
# Usage: _ph_warn [-n|-s] message...
function _ph_warn() {
  _ph_msg warning "${@}"
}

# Issue info message when ${ph_verbose} true
# Usage: _ph_info [-n|-s] message...
function _ph_info() {
  ${ph_verbose} && _ph_msg "" "${@}"
}

# Issue debug message when ${ph_debug} is true
# Usage: _ph_debug [-n|-s] message...
function _ph_debug() {
  ${ph_debug} && _ph_msg debug "${@}"
}

_ph_model=$(ph_unquote $(ph get /config/modelid))
[ $? -eq 0 ] || return 1

function ph_restart() {
  [ "${_ph_model}" == "deCONZ" ] && ph -t 10 restart ${ph_verbose:+-v}
}
