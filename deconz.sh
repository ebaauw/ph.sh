#!/bin/bash
#
# deconz.sh
# Copyright © 2017-2025 Erik Baauw. All rights reserved.
#
# Shell library for interacting with a deCONZ gateway.

# ===== CONFIGURATION ==========================================================

# Set default values.
: ${deconz_verbose:=true}
: ${deconz_debug:=false}

# ===== LIGHT STATE ============================================================

# Power-on color temperature.
deconz_ct_poweron=366       # 2,732 Kelvin

# Light recipe color temperatures.
deconz_ct_relaxed=447       # 2,237 Kelvin
deconz_ct_read=346          # 2,890 Kelvin
deconz_ct_concentrate=233   # 4,292 Kelvin
deconz_ct_energize=156      # 6,410 Kelvin

# ===== UTILITY FUNCTIONS ======================================================

# Return quoted string from string.
# Usage: s=$(deconz_quote string)
function deconz_quote() {
  [[ "${1}" == '"'*'"' ]] && echo "${1}" || echo "\"${1}\""
}

# Remove quotes from string; return unquoted string from string.
# Usage: s=$(deconz_unquote string)
function deconz_unquote() {
  [[ "${1}" == '"'*'"' ]] && eval echo "${1}" || echo "${1}"
}

# Issue message on standard error
# Usage: _deconz_msg severity [-n] [-s] message...
function _deconz_msg() {
  local start="${_deconz_host:-deconz.sh}: ${1}${1:+: }"
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
# Usage: _deconz_error [-n|-s] message...
function _deconz_error() {
  _deconz_msg error "${@}"
}

# Issue warning message
# Usage: _deconz_warn [-n|-s] message...
function _deconz_warn() {
  _deconz_msg warning "${@}"
}

# Issue info message when ${deconz_verbose} true
# Usage: _deconz_info [-n|-s] message...
function _deconz_info() {
  ${deconz_verbose} && _deconz_msg "" "${@}"
}

# Issue debug message when ${deconz_debug} is true
# Usage: _deconz_debug [-n|-s] message...
function _deconz_debug() {
  ${deconz_debug} && _deconz_msg debug "${@}"
}

function deconz_restart() {
  deconz -t 10 restart ${deconz_verbose:+-v}
}
