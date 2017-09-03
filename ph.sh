#!/bin/bash
#
# ph.sh
# Copyright © 2017 Erik Baauw. All rights reserved.
#
# Shell library for interacting with a Philips Hue or compatible bridge using
# the Philips Hue or compatible REST API.
# Currently tested on the following bridges:
# - Philips Hue v2 (square) bridge;
# - Philips Hue v1 (round) brudge;
# - dresden elektronik deCONZ REST API plugin.

# ===== CONFIGURATION ==========================================================

# Check whether json command is available, otherwise load json.sh.
json -c 0 >/dev/null 2>&1
[ $? -eq 0 ] || . json.sh

# Set default values.
: ${ph_username:=empty}
: ${ph_verbose:=false}
: ${ph_debug:=false}
: ${ph_json_args:=""}

# ===== BASIC FUNCTIONS ========================================================

# Return value for path from Philips Hue bridge on standard output.
# Path can be a full path, e.g. /lights/1/state/on, even when Philips Hue bridge
# only supports GET on resources like /lights/1.
# Usage: body=$(ph_get path)
function ph_get() {
  local resource="${1#/}"
  local path=
  local p="${resource%%/*}"
  local response

  case "${1}" in
    /groups/*/scene*)
      ;;
    *)
      case "${p}" in
        lights|groups|schedules|scenes|sensors|rules|resourcelinks)
          path="${resource#${p}}"
          path="${path#/}"
          resource="${p}"
          p="${path%%/*}"
          if [[ "${p}" == [A-Za-z0-9-]* ]] ; then
            resource="${resource}/${p}"
            path="${path#${p}}"
            path="${path#/}"
          fi
          ;;
        config|capabilities)
          path="${resource#${p}}"
          path="${path#/}"
          resource="${p}"
          ;;
        *)
          ;;
      esac
      ;;
  esac
  response=$(_ph_http GET "/${resource}")
  [ $? -eq 0 ] || return 1
  if [ -z "${path}" ] ; then
    echo "${response}" | json ${ph_json_args}
    return 0
  fi
  response=$(echo "${response}" | json ${ph_json_args} -p "${path}")
  if [ -z "${response}" ] ; then
    _ph_error "'/${path}' not found in resource '/${resource}'"
    return 1
  fi
  echo "${response}"
}

# Update resource on Philips Hue bridge.
# Usage: ph_put resource body
function ph_put() {
  local response

  response=$(_ph_http PUT "${1}" "${2}")
  [ $? -eq 0 ] || return 1
}

# Update resource on Philips Hue bridge.
# Usage: ph_patch resource body
function ph_patch() {
  local response

  if [ "${_ph_model}" != "deCONZ" ] ; then
    _ph_error "patch not supported on ${_ph_model} ${_ph_bridge}"
    return 1
  fi

  response=$(_ph_http PATCH "${1}" "${2}")
  [ $? -eq 0 ] || return 1
}

# Create resource on the Philips Hue bridge.
# Usage: id=$(ph_post resource body)
function ph_post() {
  local response

  response=$(_ph_http POST "${1}" "${2}")
  [ $? -eq 0 ] || return 1
  ph_unquote "$(json -al -c "${response}" | cut -d : -f 2)"
}

# Delete resource from the Philips Hue Bridge.
# Usage: ph_delete resource
function ph_delete() {
  local response

  response=$(_ph_http DELETE "${1}")
  [ $? -eq 0 ] || return 1
}

# ===== LIGHT STATE ============================================================

# Power-on color temperature.
ph_ct_poweron=366       # 2,732 Kelvin

# Light recipe color temperatures.
ph_ct_relaxed=447       # 2,237 Kelvin
ph_ct_read=346          # 2,890 Kelvin
ph_ct_concentrate=233   # 4,292 Kelvin
ph_ct_energize=156      # 6,410 Kelvin

# ===== BRIDGE FUNCTIONS =======================================================

# Press bridge link button (Philips Hue bridge only).
# Usage: ph_linkbutton
function ph_linkbutton() {
  if [ "${_ph_model}" == "deCONZ" ] ; then
    _ph_error "linkbutton not supported on ${_ph_model} ${_ph_bridge}"
    return 1
  fi
  ph_put /config '{"linkbutton": true}'
}

# Register ph.sh application on the bridge and create a corresponding username.
# Usage ph_username=$(ph_createuser)
function ph_createuser() {
  ph_username= ph_post / "{\"devicetype\":\"ph.sh#$(hostname -s)\"}"
}

# Perform bridge touchlink (Philips Hue bridge only).
# Usage: ph_touchlink
function ph_touchlink() {
  if [ "${_ph_model}" == "deCONZ" ] ; then
    _ph_error "touchlink not supported on ${_ph_model} ${_ph_bridge}"
    return 1
  fi
  ph_put /config '{"touchlink": true}'
}

# Reset bridge homekit status (Philips Hue v2 (square) bridge only).
# Usage: ph_reset_homekit
function ph_reset_homekit() {
  if [ "${_ph_model}" != "BSB002" ] ; then
    _ph_error "touchlink not supported on ${_ph_model} ${_ph_bridge}"
    return 1
  fi
  ph_put /config '{"homekit":{"factoryreset": true}}'
}

# Restart the deCONZ gateway.
# Usage: ph_restart
function ph_restart() {
  if [ "${_ph_model}" != "deCONZ" ] ; then
    _ph_error "restart not supported on ${_ph_model} ${_ph_bridge}"
    return 1
  fi
  local response=$(ph_post /config/restartapp)
  if [ ${response} == "true" ] ; then
    _ph_info -n "restarting ${_ph_model} ${_ph_bridge} "
    while [ "${response}" != "\"${_ph_model}\"" ] ; do
      _ph_info -n -s "."
      sleep 1
      response="$(ph_get /config/modelid 2>/dev/null)"
    done
    _ph_info -s
  fi
}

# ===== BRIDGE DISCOVERY =======================================================

# Set ${_ph_host} and ${_ph_model} for bridge/gateway at host.
# Usage: ph_host [host]
function ph_host() {
  config="$(_ph_host=${1:-${_ph_host}} ph_config)"
  [ $? -eq 0 ] || return 1
  _ph_host=${1:-${_ph_host}}
  _ph_model="$(ph_unquote $(json -p /modelid -c "${config}"))"
  _ph_bridge=bridge
  local version="$(ph_unquote $(json -p /swversion -c "${config}"))"
  local api="$(ph_unquote $(json -p /apiversion -c "${config}"))"
  [ "${_ph_model}" == "deCONZ" ] && _ph_bridge=gateway
  version="$(ph_unquote ${version})"
  api="$(ph_unquote ${api})"
  _ph_info "${_ph_model} ${_ph_bridge} v${version}, api v${api}"
  [ -z "${1}" ] && echo "\"${_ph_host}\""
}

# Find a bridge/gateway.
# Usage: ph_findhost
function ph_findhost() {
  # Check whether host is a valid bridge/gateway.  Call ph_host when it is.
  # Usage: probe host
  function probe_host() {
    _ph_host= _ph_info -n "probing ${1} ..."
    _ph_host="${1}" ph_config >/dev/null 2>&1
    if [ $? -ne 0 ] ; then
      _ph_info -s " no bridge/gateway found"
      return 1
    fi
    _ph_info -s " ok"
    ph_host "${1}"
    return 0
  }

  # Check whether (one of) the bridge(s)/gateway(s) return by the portal is a
  # valid bridge/gateway.
  # Usage: probe_hosts response
  function probe_hosts() {
    local i=0
    local host="$(ph_unquote "$(json -avc "${1}" -p /${i}/internalipaddress)")"
    while [ ! -z "${host}" ] ; do
      local -i port="$(json -avc "${1}" -p /${i}/internalport)"
      [ ${port} -eq 0 -o ${port} -eq 80 ] || host="${host}:${port}"
      probe_host "${host}"
      [ $? -eq 0 ] && return 0
      i=$((i + 1))
      host="$(ph_unquote "$(json -avc "${1}" -p /${i}/internalipaddress)")"
    done
    return 1
  }

  # Try localhost.
  probe_host localhost
  [ $? -eq 0 ] && return 0

  # Try meethue portal.
  _ph_host= _ph_info "contacting meethue portal ..."
  probe_hosts "$(ph_nupnp)"
  [ $? -eq 0 ] && return 0

  # Try deCONZ portal over IPv4.
  _ph_host= _ph_info "contacting deCONZ portal over IPv4 ..."
  probe_hosts "$(ph_nupnp_deconz -4)"
  [ $? -eq 0 ] && return 0

  # Try deCONZ portal over IPv6.
  _ph_host= _ph_info "contacting deCONZ portal over IPv6 ..."
  probe_hosts "$(ph_nupnp_deconz -6)"
  [ $? -eq 0 ] && return 0
}

# Find Philips Hue bridges through the meethue portal (nupnp method).
# Usage: ph_nupnp
function ph_nupnp() {
  local cmd
  local response

  cmd="curl -s -H \"Content-Type: application/json\""
  cmd="${cmd} \"https://www.meethue.com/api/nupnp\""
  _ph_host= _ph_debug "meethue portal command: ${cmd}"
  response=$(eval ${cmd})
  if [ $? -ne 0 ] ; then
    _ph_host= _ph_error "meethue portal not found"
    return 1
  fi
  _ph_host= _ph_debug "meethue portal response: ${response}"
  json ${ph_json_args} -c "${response}"
}

# Find deCONZ bridges through the dresden elektronik portal (nupnp method).
# Usage: ph_nupnp_deconz [-4|-6]
function ph_nupnp_deconz() {
  local cmd
  local response

  cmd="curl -s -H \"Content-Type: application/json\""
  [ "${1}" == "-4" -o "${1}" == "-6" ] && cmd="${cmd} ${1}"
  cmd="${cmd} \"https://dresden-light.appspot.com/discover\""
  _ph_host= _ph_debug "deCONZ portal command: ${cmd}"
  response=$(eval ${cmd})
  if [ $? -ne 0 ] ; then
    _ph_host= _ph_error "deCONZ portal not found"
    return 1
  fi
  _ph_host= _ph_debug "deCONZ portal response: ${response}"
  json ${ph_json_args} -c "${response}"
}

# Show bridge UPnP description.
# Usage: ph_description
function ph_description {
  local cmd
  local response

  if [ -z "${_ph_host}" ] ; then
    _ph_error "host not set - please run ph_host"
    return 1
  fi
  cmd="curl -s \"http://${_ph_host}/description.xml\""
  _ph_debug "${_ph_bridge} command: ${cmd}"
  response=$(eval ${cmd})
  if [ $? -ne 0 ] ; then
    _ph_error "${_ph_bridge} ${_ph_host} not found"
    return 1
  fi
  _ph_debug "${_ph_bridge} response: ${response}"
  echo "${response}"
}

# Unauthorised config (Philips Hue bridge only).
# Usage: ph_config
function ph_config() {
  ph_username= ph_get /config
}

# ===== LIGHT VALUES ===========================================================

# Discover values for ct and xy supported by light.
# Usage: ph_light_values id
function ph_light_values() {
  local light="/lights/${1}"
  local state="${light}/state"
  local response
  response=$(ph_get "/lights/${1}")
  [ $? -eq 0 ] || return 1

  local manufacturer="$(json -c "${response}" -p /manufacturername)"
  [ -z "${manufacturer}" ] && manufacturer="$(json -c "${response}" -p /manufacturer)"
  manufacturer="$(ph_unquote "${manufacturer}")"
  local model="$(ph_unquote "$(json -c "${response}" -p /modelid)")"
  local ltype="$(ph_unquote "$(json -c "${response}" -p /type)")"
  local name="$(json -c "${response}" -p /name)"
  local bri="$(json -c "${response}" -p /state/bri)"
  local ct="$(json -c "${response}" -p /state/ct)"
  local xy="$(json -nc "${response}" -p /state/xy)"

  _ph_info "${light}: ${manufacturer} ${model} ${ltype} ${name}"

  local ct
  local ct_min
  local ct_max
  local xy
  local xy_red
  local xy_green
  local xy_blue

  local -i max=0
  local zero="0.0000"
  local one="1.0000"
  if [ "${_ph_model}" == "deCONZ" ] ; then
    max=60
    zero="0"
    one="1"
  fi

  function ct_value() {
    _ph_info -n "${light}: ct: ${1} .."
    ph_put "${state}" "{\"ct\":${2}}"
    ct=$(ph_get "${state}/ct")
    local -i n=0
    while [ "${ct}" == "${2}" -a ${n} -le ${max} ] ; do
      _ph_info -n -s .
      sleep 5
      ct=$(ph_get "${state}/ct")
      n=$((n + 1))
    done
    _ph_info -s " ${ct}"
  }

  function xy_value() {
    _ph_info -n "${light}: xy: ${1} .."
    ph_put "${state}" "{\"xy\":${2}}"
    xy=$(ph_json_args=-n ph_get "${state}/xy")
    while [ "${xy}" == "${2}" ] ; do
      _ph_info -n -s .
      sleep 5
      xy=$(ph_json_args=-n ph_get "${state}/xy")
    done
    _ph_info -s " ${xy}"
  }

  ph_put "${state}" '{"on":true}'

  if [ ! -z "${ct}" ] ; then
    ct_value cool 153
    ct_min="${ct}"
    ct_value warm 500
    ct_max="${ct}"
  fi

  if [ ! -z "${xy}" ] ; then
    xy_value red "[${one},${zero}]"
    xy_red="${xy}"
    xy_value green "[${zero},${one}]"
    xy_green="${xy}"
    xy_value blue "[${zero},${zero}]"
    xy_blue="${xy}"
  fi

  ph_put "${state}" '{"on":false}'
  _ph_info "${light}: done"

  local s="{"
  s="${s}\"manufacturer\": \"${manufacturer}\""
  s="${s},\"modelid\": \"${model}\""
  s="${s},\"type\": \"${ltype}\""
  if [ ! -z "${bri}" ] ; then
    s="${s},\"bri\":true"
  fi
  if [ ! -z "${ct}" ] ; then
    s="${s},\"ct\":{\"min\":${ct_min},\"max\":${ct_max}}"
  fi
  if [ ! -z "${xy}" ] ; then
    s="${s},\"xy\":{\"r\":${xy_red},\"g\":${xy_green},\"b\":${xy_blue}}"
  fi
  s="${s}}"
  json -c "${s}"
}

# ===== UTILITY FUNCTIONS ======================================================

# Issue a HTTP command to the bridge and return response.
# Note response is returned only when bridge command succeeded.  Otherwise a
# message is printed on standard error and a non-zero status is returned.
# Usage: response=$(ph_http GET|PUT|PATCH|POST|DELETE resource [body])
function _ph_http() {
  local resource
  local method
  local data
  local cmd
  local response
  local responselines
  local errorlines

  # Check parameters
  case "${1}" in
    GET)
      method=
      data=
      ;;
    PUT|PATCH|POST)
      method=" -X ${1}"
      if [ -z "${3}" ] ; then
        data=
      else
        data=$(json -nc "${3}" 2>/dev/null)
        if [[ $? -ne 0 || "${data}" != {*} ]] ; then
          _ph_error "invalid body '${3}'"
          return 1
        fi
        data=" -d '${3}'"
      fi
      ;;
    DELETE)
      method=" -X ${1}"
      data=
      ;;
    *)
      _ph_error "invalid method '${1}'"
      return 1
      ;;
  esac
  if [[ "${2}" != /* ]] ; then
    _ph_error "invalid resource '${2}'"
    return 1
  fi
  if [ "${ph_username}" == empty ] ; then
    _ph_error "ph_username not set"
    return 1
  elif [ -z "${ph_username}" ] ; then
    resource="/api${2}"
  else
    resource="/api/${ph_username}${2}"
  fi
  if [ -z "${_ph_host}" ] ; then
    _ph_error "host not set - please run ph_host"
    return 1
  fi

  # Send HTTP request to the Hue bridge.
  cmd="curl -s${method} -H \"Content-Type: application/json\"${data}"
  cmd="${cmd} \"http://${_ph_host}${resource}\""
  _ph_debug "${_ph_bridge} command: ${cmd}"
  response=$(eval ${cmd})
  if [ $? -ne 0 ] ; then
    _ph_error "${_ph_bridge} not found"
    return 1
  fi
  _ph_debug "${_ph_bridge} response: ${response}"

  # Check response for errors.
  responselines=$(echo "${response}" | json -al 2>/dev/null)
  if [ $? -ne 0 -o "${response}" == '[]' ] ; then
    _ph_error "invalid method ${1} for resource ${2}"
    return 1
  fi
  errorlines=$(echo "${responselines}" | grep /error/type: | cut -d / -f 2)
  if [ ! -z "${errorlines}" ] ; then
    for i in ${errorlines} ; do
      local -i errno="$(json -avp /${i}/error/type -c "${response}")"
      local error="$(json -avp /${i}/error/description -c "${response}")"
      error="$(ph_unquote "${error}")"
      _ph_error "${_ph_bridge} error ${errno}: ${error}"
    done
    return 1
  fi

  # Output response.
  echo "${response}"
}

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
