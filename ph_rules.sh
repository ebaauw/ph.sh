#!/bin/bash
#
# ph_rules.sh
# Copyright © 2017-2020 Erik Baauw. All rights reserved.
#
# Create/configure rules on the Hue bridge or deCONZ gateway.
#
# Room Status:
# -2  Wakeup
# -1  Disabled
# 0   No presence
# 1   Presence
# 2   Pending no presence
# 3   Presence in adjacent room
# 4   TV

. ph.sh
if [ $? -ne 0 ] ; then
  _ph_error "cannot load ph.sh"
fi

# Usage: ph_rule name conditions actions
function ph_rule() {
  local name="${1}"
  local conditions="${2}"
  local actions="${3}"
  local body="{
    \"name\": \"${name}\",
    \"status\": \"enabled\",
    \"conditions\": ${conditions},
    \"actions\": ${actions}
  }"
  local -i id=$(ph_unquote $(ph -t 10 post "/rules" "${body}"))
  if [ ${id} -eq 0 ] ; then
    _ph_error "cannot create rule \"${name}\""
    json -c "${body}" >&2
    return 1
  fi
  _ph_info "/rules/${id}: \"${name}\""
}

# Usage: ph_rules_delete
function ph_rules_delete() {
  local -i rule
  local rules="$(ph get -al /rules | grep /name: | cut -d / -f 2)"
  local -i nrules=$(echo ${rules} | wc -w)
  _ph_info "deleting ${nrules} rules..."
  for rule in ${rules}; do
    ph delete /rules/${rule}
  done
  ph_restart
}

# Usage: nrules=$(ph_rules_count)
function ph_rules_count() {
  local -i nrules=$(ph get -al /rules | grep /name: | wc -l)
  echo ${nrules}
}

# ===== Conditions =============================================================

# Usage: condition="$(ph_condition address [[operator] value | 'dx'])"
function ph_condition() {
  if [ -z "${3}" ] ; then
    if [ "${2}" == dx ] ; then
      echo "{
        \"address\": \"${1}\",
        \"operator\": \"${2}\"
      }"
    else
      echo "{
        \"address\": \"${1}\",
        \"operator\": \"eq\",
        \"value\": \"${2}\"
      }"
    fi
  else
    echo "{
      \"address\": \"${1}\",
      \"operator\": \"${2}\",
      \"value\": \"${3}\"
    }"
  fi
}

# Usage: condition="$(ph_condition_sensor id attribute [[operator] value | 'dx'])"
function ph_condition_sensor() {
  ph_condition "/sensors/${1}/state/${2}" "${3}" "${4}"
}

# Usage: condition="$(ph_condition_sensor_config id attribute [[operator] value | 'dx'])"
function ph_condition_sensor_config() {
  ph_condition "/sensors/${1}/config/${2}" "${3}" "${4}"
}

# Usage: condition="$(ph_condition_light id attribute [[operator] value | 'dx'])"
function ph_condition_light() {
  ph_condition "/lights/${1}/state/${2}" "${3}" "${4}"
}

# Usage: condition="$(ph_condition_group id attribute [[operator] value | 'dx'])"
function ph_condition_group() {
  ph_condition "/groups/${1}/state/${2}" "${3}" "${4}"
}

# Usage: condition="$(ph_condition_config attribute [[operator] value | 'dx'])"
function ph_condition_config() {
  ph_condition "/config/${1}" "${2}" "${3}"
}

# Usage: condition="$(ph_condition_dx sensor [attribute])"
function ph_condition_dx() {
  ph_condition_sensor "${1}" "${2:-lastupdated}" dx
}

# Usage: condition="$(ph_condition_ddx sensor [attribute] time)"
function ph_condition_ddx() {
  if [ -z "${3}" ] ; then
    ph_condition_sensor "${1}" lastupdated ddx "PT${2}"
  else
    ph_condition_sensor "${1}" "${2}" ddx "PT${3}"
  fi
}

# Usage: condition="$(ph_condition_on light [value])"
function ph_condition_on() {
  ph_condition_light "${1}" on eq "${2:-true}"
}

# Usage: condition="$(ph_condition_allon group [value])"
function ph_condition_allon() {
  ph_condition_group  "${1}" all_on eq "${2:-true}"
}

# Usage: condition="$(ph_condition_anyon group [value])"
function ph_condition_anyon() {
  ph_condition_group  "${1}" any_on eq "${2:-true}"
}

# Usage: condition="$(ph_condition_flag sensor [value])"
function ph_condition_flag() {
  ph_condition_sensor "${1}" flag eq "${2:-true}"
}

# Usage: condition="$(ph_condition_motion sensor [value])"
function ph_condition_motion() {
  ph_condition_sensor "${1}" presence eq "${2:-true}"
}

# Usage: condition="$(ph_condition_vibration sensor [value])"
function ph_condition_vibration() {
  ph_condition_sensor "${1}" vibration eq "${2:-true}"
}

# Usage: condition="$(ph_condition_dark sensor [value])"
function ph_condition_dark() {
  ph_condition_sensor "${1}" dark eq "${2:-true}"
}

# Usage: condition="$(ph_condition_daylight sensor [value])"
function ph_condition_daylight() {
  ph_condition_sensor "${1}" daylight eq "${2:-true}"
}

# Usage: condition="$(ph_condition_open sensor [value])"
function ph_condition_open() {
  ph_condition_sensor "${1}" open eq "${2:-true}"
}

# Usage: condition="$(ph_condition_status sensor [op] value)"
function ph_condition_status() {
  ph_condition_sensor "${1}" status "${2}" "${3}"
}

# Usage: condition="$(ph_condition_temperature sensor [op] value)"
function ph_condition_temperature() {
  ph_condition_sensor "${1}" temperature "${2}" "${3}"
}

# Usage: condition="$(ph_condition_humidity sensor [op] value)"
function ph_condition_humidity() {
  ph_condition_sensor "${1}" humidity "${2}" "${3}"
}

# Usage: condition="$(ph_condition_pressure sensor [op] value)"
function ph_condition_pressure() {
  ph_condition_sensor "${1}" pressure "${2}" "${3}"
}

# Usage: condition="$(ph_condition_localtime [op] from to)"
function ph_condition_localtime() {
  if [ -z "${3}" ] ; then
    ph_condition_config localtime in "T${1}/T${2}"
  else
    ph_condition_config localtime "${1}" "T${2}/T${3}"
  fi
}

# Usage: condition="$(ph_condition_buttonevent sensor value [value])"
function ph_condition_buttonevent() {
  if [ -z "${3}" ] ; then
    echo $(ph_condition_sensor "${1}" buttonevent "${2}"),
  else
    echo $(ph_condition_sensor "${1}" buttonevent gt" ${2}"),
    echo $(ph_condition_sensor "${1}" buttonevent lt "${3}"),
  fi
  ph_condition_dx "${1}"
}

# ===== Actions ================================================================

# Usage: action="$(ph_action address [method] [body])"
function ph_action() {
  if [ -z "${3}" ] ; then
    if [ -z "${2}" -o "${2}" == PUT -o "${2}" == POST ] ; then
      echo "{
        \"address\": \"${1}\",
        \"method\": \"${2:-PUT}\"
      }"
    else
      echo "{
        \"address\": \"${1}\",
        \"method\": \"PUT\",
        \"body\": ${2}
      }"
    fi
  else
    echo "{
      \"address\": \"${1}\",
      \"method\": \"${2}\",
      \"body\": ${3}
    }"
  fi
}

# Usage: action="$(ph_action_sensor_state id [method] [body])"
function ph_action_sensor_state() {
  ph_action "/sensors/${1}/state"  "${2}" "${3}"
}

# Usage: action="$(ph_action_sensor_config id [method] [body])"
function ph_action_sensor_config() {
  ph_action "/sensors/${1}/config" "${2}" "${3}"
}

# Usage: action="$(ph_action_light_state id [method] [body])"
function ph_action_light_state() {
  ph_action "/lights/${1}/state"   "${2}" "${3}"
}

# Usage: action="$(ph_action_group_action id [method] [body])"
function ph_action_group_action() {
  ph_action "/groups/${1}/action"  "${2}" "${3}"
}

# Usage: condition="$(ph_action_flag sensor [value])"
function ph_action_flag() {
  ph_action_sensor_state  "${1}" "{\"flag\": ${2:-true}}"
}

# Usage: action="$(ph_action_status sensor value)"
function ph_action_status() {
  ph_action_sensor_state "${1}" "{\"status\": ${2}}"
}

# Usage: action="$(ph_action_light_on light [value])"
function ph_action_light_on() {
  ph_action_light_state  "${1}" "{\"on\": ${2:-true}}"
}

# Usage: condition="$(ph_action_light_state light [value])"
function ph_action_light_open() {
  ph_action_light_state  "${1}" "{\"open\": ${2:-true}}"
}

# Usage: action="$(ph_action_light_bri light [value])"
function ph_action_light_bri() {
  ph_action_light_state  "${1}" "{\"bri\": ${2:-254}}"
}

# Usage: condition="$(ph_action_group_on group [value])"
function ph_action_group_on() {
  ph_action_group_action  "${1}" "{\"on\": ${2:-true}}"
}

# Usage: condition="$(ph_action_group_open group [value])"
function ph_action_group_open() {
  ph_action_group_action  "${1}" "{\"open\": ${2:-true}}"
}

# Usage: action="$(ph_action_group_alert group [value])"
function ph_action_group_alert() {
  ph_action_group_action  "${1}" "{\"alert\": \"${2:-select}\"}"
}

# Usage: action="$(ph_action_sensor_alert sensor [value])"
function ph_action_sensor_alert() {
  ph_action_sensor_config "${1}" "{\"alert\": \"${2:-select}\"}"
}

# Usage: action=$(ph_action_heatsetpoint sensor value)
function ph_action_heatsetpoint() {
  ph_action_sensor_config "${1}" "{\"heatsetpoint\": ${2}}"
}

# Usage: action="$(ph_action_light_dim group [up|down|stop|wakeup])"
function ph_action_group_dim() {
  local -i value
  local -i tt
  local -i hb
  local bri_inc

  case "${2}" in
    up)     value=254  ; tt=20   ;;
    down)   value=-254 ; tt=20   ;;
    stop)   value=0    ; tt=0    ;;
    wakeup) value=254  ; tt=6000 ;;
  esac
  [ "${_ph_model}" == "deCONZ" ] && bri_inc=bri || bri_inc=bri_inc
  ph_action_group_action "${1}" "{\"${bri_inc}\": ${value}, \"transitiontime\": ${tt}}"
}

# Usage: action="$(ph_action_scene group scene)"
function ph_action_scene_recall() {
  if [ "${_ph_model}" == "deCONZ" ] ; then
    ph_action "/groups/${1}/scenes/${2}/recall"
  else
    ph_action_group_action "${1}" "{\"scene\": \"${2}\"}"
  fi
}

# ===== Mirror =================================================================

# ph_rules_mirror name flag host apikey
function ph_rules_mirror() {
  local name="${1}"
  local -i flag="${2}"
  local host="${3}"
  local apikey = "${4}"

  ph_rule "Mirror ${name} Off" "[
    $(ph_condition_flag ${flag} false)
  ]" "[
    $(ph_action http://${host}/api/${apikey}/sensors/${flag}/state PUT '{"flag": false}')
  ]"
  ph_rule "Mirror ${name} On" "[
    $(ph_condition_flag ${flag})
  ]" "[
    $(ph_action http://${host}/api/${apikey}/sensors/${flag}/state PUT '{"flag": true}')
  ]"
}

# ===== Boot ===================================================================

# On startup, all CLIP sensors are initialised to 0.  Then the Hue bridge
# updates the built-in Daylight sensor.  We can use this to detect that the
# Hue bridge has booted.  We keep a CLIPGenericFlag sensor (boottime) which is
# set to true when the Daylight sensor changes while boottime is 0.  As we never
# change boottime afterwards, it's state.lastupdated attribute reflects boot
# time.
# Assuming the Hue bridge reboots because power has just been restored after a
# power outage, we'll also set the power restored flag turn off all lights.

# Usage: ph_rules_boottime boottime [flag] [daylight]
function ph_rules_boottime() {
  local -i boottime="${1}"
  local -i flag="${2}"
  local -i daylight="${3:-1}"

  if [ -z "${2}" ] ; then
    ph_rule "Boot Time" "[
      $(ph_condition_dx ${daylight}),
      $(ph_condition_flag ${boottime} false)
    ]" "[
      $(ph_action_flag ${boottime})
    ]"
  else
    ph_rule "Boot Time" "[
      $(ph_condition_dx ${daylight}),
      $(ph_condition_flag ${boottime} false)
    ]" "[
      $(ph_action_flag ${boottime}),
      $(ph_action_flag ${flag})
    ]"
  fi
}

# ===== Night and Day ==========================================================

# Usage: ph_rules_night boottime night [daylight [morning evening]]
function ph_rules_night() {
  local -i boottime=${1}
  local -i night=${2}
  local -i daylight=${3:-1}
  local morning="${4:-07:00:00}"
  local evening="${5:-23:00:00}"

  ph_rule "Daylight On" "[
    $(ph_condition_daylight ${daylight})
  ]" "[
    $(ph_action_flag ${night} false)
  ]"

  ph_rule "Night On" "[
    $(ph_condition_flag ${boottime}),
    $(ph_condition_localtime ${evening} ${morning})
  ]" "[
    $(ph_action_flag ${night})
  ]"

  # ph_rule "Night Off" "[
  #   $(ph_condition_flag ${boottime}),
  #   $(ph_condition_localtime ${morning} ${evening})
  # ]" "[
  #   $(ph_action_flag ${night} false)
  # ]"
}

# ===== Power Restore ==========================================================

# Usage: ph_rules_power flag [group]
# Flag is true when power has been restored.
function ph_rules_power() {
  local -i flag="${1}"
  local -i group="${2:-0}"

  ph_rule "Power 1/5" "[
    $(ph_condition_flag ${flag}),
    $(ph_condition_dx ${flag})
  ]" "[
    $(ph_action_group_on ${group} false)
  ]"

  ph_rule "Power 2/5" "[
    $(ph_condition_flag ${flag}),
    $(ph_condition_ddx ${flag} "00:00:02")
  ]" "[
    $(ph_action_group_on ${group} false)
  ]"

  ph_rule "Power 3/5" "[
    $(ph_condition_flag ${flag}),
    $(ph_condition_ddx ${flag} "00:00:04")
  ]" "[
    $(ph_action_group_on ${group} false)
  ]"

  ph_rule "Power 4/5" "[
    $(ph_condition_flag ${flag}),
    $(ph_condition_ddx ${flag} "00:00:06")
  ]" "[
    $(ph_action_group_on ${group} false)
  ]"

  ph_rule "Power 5/5" "[
    $(ph_condition_flag ${flag}),
    $(ph_condition_ddx ${flag} "00:00:08")
  ]" "[
    $(ph_action_group_on ${group} false),
    $(ph_action_flag ${flag} false)
  ]"
}

# ===== Room Status ============================================================

# For each room, we keep a CLIPGenericFlag sensor (flag), as virtual master
# switch, and a CLIPGenericStatus sensor (status), to store the room state:
#
# status   state                       room  automation
# ======   =========================   ====  ==========
#    -2    wakeup in progress          off   off
#    -1    disabled                    off   off
#     0    no presence                 off   on
#     1    presence                    on    on
#     2    presence in adjacent room   on    on
#     3    pending no presence         on    on
#
# The status is maintained from motion sensors, door sensors, and switches.
# The flag is maintained automatically, from the status, or manually from
# HomeKit where the flag is exposed as switch.  The lights are controlled from
# the flag (in combination with the time of day and lightlevel).

# Usage: ph_rules room status flag [group]
function ph_rules_status() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i group=${4}

  ph_rule "${room} Off" "[
    $(ph_condition_flag ${flag} false),
    $(ph_condition_dx ${flag}),
    $(ph_condition_status ${status} gt 0)
  ]" "[
    $(ph_action_status ${status} 0)
  ]"

  ph_rule "${room} Status <1" "[
    $(ph_condition_status ${status} lt 1)
  ]" "[
    $(ph_action_flag ${flag} false)
  ]"

  ph_rule "${room} Status >0" "[
    $(ph_condition_status ${status} gt 0)
  ]" "[
    $(ph_action_flag ${flag})
  ]"

  if [ ! -z "${4}" ] ; then
    ph_rule "${room} Status 2" "[
      $(ph_condition_status ${status} 2),
      $(ph_condition_ddx ${status} "00:00:15")
    ]" "[
      $(ph_action_status ${status} 1)
    ]"

    ph_rule "${room} Status 3 (1/3)" "[
      $(ph_condition_status ${status} 3),
      $(ph_condition_ddx ${status} "00:04:00"),
      $(ph_condition_flag ${flag})
    ]" "[
      $(ph_action_group_alert ${group} breathe)
    ]"

    ph_rule "${room} Status 3 (2/3)" "[
      $(ph_condition_status ${status} 3),
      $(ph_condition_ddx ${status} "00:04:01"),
      $(ph_condition_flag ${flag})
    ]" "[
      $(ph_action_group_alert ${group} finish)
    ]"

    ph_rule "${room} Status 3 (3/3)" "[
      $(ph_condition_status ${status} 3),
      $(ph_condition_ddx ${status} "00:05:00")
    ]" "[
      $(ph_action_status ${status} 0)
    ]"
  fi
}

# Usage: ph_rules_wakeup room status flag group night scene
function ph_rules_wakeup() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i group=${4}
  local -i night=${5}
  local scene="${6}"

  ph_rule "${room} Wakeup 1/3" "[
    $(ph_condition_status ${status} -2)
  ]" "[
    $(ph_action_scene_recall ${group} ${scene}),
    $(ph_action_flag ${night} false)
  ]"

  ph_rule "${room} Wakeup 2/3" "[
    $(ph_condition_status ${status} -2),
    $(ph_condition_ddx ${status} status "00:00:10")
  ]" "[
    $(ph_action_group_dim ${group} wakeup)
  ]"

  ph_rule "${room} Wakeup 3/3" "[
    $(ph_condition_status ${status} -2),
    $(ph_condition_ddx ${status} status "00:10:10")
  ]" "[
    $(ph_action_status ${status} 1)
  ]"
}

# ===== Motion Sensors =========================================================

# We use two different patterns for motion sensors:
# - For hallways (where you never sit still), the room status is set to no
#   presence when motion hasn't been detected for 1 minute;
# - For rooms (where you sit still), the room is set to no presence when
#   motion hasn't been detected for 5 minutes, after some-one has left the room.
#   This is detected by a sequence of motion detected in room (status 1), motion
#   detected in adjacent room (status 2), no more motion detected in room within
#   15 seconds (status 3).  A warning is given at 1 minute's notice before the
#   lights are turned off.

# Usage: ph_rules_motion room status flag motion [timeout]
function ph_rules_motion() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i motion=${4}
  local timeout=${5}

  if [ -z "${timeout}" ] ; then
    ph_rule "${room} Motion Clear" "[
      $(ph_condition_motion ${motion} false),
      $(ph_condition_dx ${motion} presence),
      $(ph_condition_status ${status} 2)
    ]" "[
      $(ph_action_status ${status} 3)
    ]"
    ph_rule "${room} No Motion" "[
      $(ph_condition_motion ${motion} false),
      $(ph_condition_ddx ${motion} presence "00:55:00"),
      $(ph_condition_status ${status} gt 0),
      $(ph_condition_status ${status} lt 4)
    ]" "[
      $(ph_action_status ${status} 3)
    ]"
  else
    ph_rule "${room} Motion Clear" "[
      $(ph_condition_motion ${motion} false),
      $(ph_condition_ddx ${motion} presence ${timeout}),
      $(ph_condition_status ${status} gt 0),
      $(ph_condition_status ${status} lt 4)
    ]" "[
      $(ph_action_status ${status} 0)
    ]"
  fi
  ph_rule "${room} Motion Detected" "[
    $(ph_condition_motion ${motion}),
    $(ph_condition_dx ${motion} presence),
    $(ph_condition_status ${status} gt -1),
    $(ph_condition_status ${status} lt 4)
  ]" "[
    $(ph_action_status ${status} 1)
  ]"
}

# Usage: ph_rules_vibration room status flag vibration [timeout]
function ph_rules_vibration() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i vibration=${4}
  local timeout=${5}

  ph_rule "${room} Vibration Detected" "[
    $(ph_condition_vibration ${vibration}),
    $(ph_condition_dx ${vibration} vibration),
    $(ph_condition_status ${status} gt -1),
    $(ph_condition_status ${status} lt 4)
  ]" "[
    $(ph_action_status ${status} 1)
  ]"
}

# Usage: ph_rules_room room status room2 motion
function ph_rules_leave_room() {
  local room="${1}"
  local -i status=${2}
  local room2="${3}"
  local -i motion=${4}

  ph_rule "${room} to ${room2}" "[
    $(ph_condition_motion ${motion}),
    $(ph_condition_dx ${motion} presence),
    $(ph_condition_status ${status} 1)
  ]" "[
    $(ph_action_status ${status} 2)
  ]"
}

# ===== Door Sensors ===========================================================

# Usage: ph_rules_room room status flag door [noclose]
function ph_rules_door() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i door=${4}
  local noclose="${5}"

  if [ -z "${noclose}" ] ; then
    ph_rule "${room} Door Close" "[
      $(ph_condition_open ${door} false),
      $(ph_condition_dx ${door} open),
      $(ph_condition_status ${status} gt -1)
    ]" "[
      $(ph_action_status ${status} 0)
    ]"
  fi

  ph_rule "${room} Door Open" "[
    $(ph_condition_open ${door}),
    $(ph_condition_dx ${door} open),
    $(ph_condition_status ${status} gt -1)
  ]" "[
    $(ph_action_status ${status} 1)
  ]"
}

# ===== Switches ===============================================================

# Usage: ph_rules_dimmer_onoff room status flag dimmer motion group scene
function ph_rules_dimmer_onoff() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i dimmer=${4}
  local -i motion=${5}
  local -i group=${6}
  local -i scene=${7}

  ph_rule "${room} Dimmer Off Press" "[
    $(ph_condition_buttonevent ${dimmer} 4002)
  ]" "[
    $(ph_action_status ${status} 0)
  ]"

  # Disable room automation.  Flash motion sensor light as confirmation.
  ph_rule "${room} Dimmer Off Hold" "[
    $(ph_condition_buttonevent ${dimmer} 4001)
  ]" "[
    $(ph_action_sensor_alert ${motion}),
    $(ph_action_status ${status} -1)
  ]"

  ph_rule "${room} Dimmer On Press" "[
    $(ph_condition_buttonevent ${dimmer} 1002)
  ]" "[
    $(ph_action_status ${status} 1)
  ]"

  # Set default scene.
  ph_rule "${room} Dimmer On Hold" "[
  $(ph_condition_buttonevent ${dimmer} 1001)
  ]" "[
    $(ph_action_scene_recall ${group} ${scene})
  ]"
}

# Usage: ph_rules_switch_toggle room status flag switch
function ph_rules_switch_toggle() {
  local room="${1}"
  local -i status=${2}
  local -i flag=${3}
  local -i switch=${4}

  ph_rule "${room} Switch On/Off Press (1/2)" "[
    $(ph_condition_buttonevent ${switch} 1002),
    $(ph_condition_status ${status} gt 0)
  ]" "[
    $(ph_action_status ${status} 0)
  ]"

  ph_rule "${room} Switch On/Off Press (2/2)" "[
    $(ph_condition_buttonevent ${switch} 1002),
    $(ph_condition_status ${status} lt 1)
  ]" "[
    $(ph_action_status ${status} 1)
  ]"
}

# Usage: ph_rules_dimmer_updown room dimmer group
function ph_rules_dimmer_updown() {
  local room="${1}"
  local -i dimmer=${2}
  local -i group=${3}

  ph_rule "${room} Dimmer Up Press" "[
    $(ph_condition_buttonevent ${dimmer} 2000)
  ]" "[
    $(ph_action_group_dim ${group} up)
  ]"

  ph_rule "${room} Dimmer Up Release" "[
    $(ph_condition_buttonevent ${dimmer} 2001 2004)
  ]" "[
    $(ph_action_group_dim ${group} stop)
  ]"

  ph_rule "${room} Dimmer Down Press" "[
    $(ph_condition_buttonevent ${dimmer} 3000)
  ]" "[
    $(ph_action_group_dim ${group} down)
  ]"

  ph_rule "${room} Dimmer Down Release" "[
    $(ph_condition_buttonevent ${dimmer} 3001 3004)
  ]" "[
    $(ph_action_group_dim ${group} stop)
  ]"
}

# ===== Lights =================================================================

# Usage: ph_rules_light room flag group night default nightmode [lightlevel [status tv]]
function ph_rules_light() {
  local room="${1}"
  local -i flag=${2}
  local -i group=${3}
  local -i night=${4}
  local default="${5}"
  local nightmode="${6}"
  local -i lightlevel=${7}
  local -i status=${8}
  local tv="${9}"

  ph_rule "${room} Off" "[
    $(ph_condition_flag ${flag} false)
  ]" "[
    $(ph_action_group_on ${group} false)
  ]"

  if [ -z "${7}" ] ; then
    ph_rule "${room} On, Day" "[
      $(ph_condition_flag ${flag}),
      $(ph_condition_flag ${night} false)
    ]" "[
      $(ph_action_scene_recall ${group} ${default})
    ]"

    ph_rule "${room} On, Night" "[
      $(ph_condition_flag ${flag}),
      $(ph_condition_flag ${night})
    ]" "[
      $(ph_action_scene_recall ${group} ${nightmode})
    ]"

    return
  fi

  local type=$(ph_unquote $(ph get "/sensors/${lightlevel}/type"))
  if [ "${type}" == "Daylight" ] ; then
    if [ "${_ph_model}" == "deCONZ" ] ; then
      # lightlevel is Daylight sensor on deCONZ gateway
      ph_rule "${room} On, Not Dark" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_status ${lightlevel} gt 125),
        $(ph_condition_status ${lightlevel} lt 205)
      ]" "[
        $(ph_action_group_on ${group} false)
      ]"

      ph_rule "${room} On, Dark 1, Day" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_status ${lightlevel} lt 125),
        $(ph_condition_flag ${night} false)
      ]" "[
        $(ph_action_scene_recall ${group} ${default})
      ]"

      ph_rule "${room} On, Dark 2, Day" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_status ${lightlevel} gt 205),
        $(ph_condition_flag ${night} false)
      ]" "[
        $(ph_action_scene_recall ${group} ${default})
      ]"

      ph_rule "${room} On, Dark 1, Night" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_status ${lightlevel} lt 125),
        $(ph_condition_flag ${night})
      ]" "[
        $(ph_action_scene_recall ${group} ${nightmode})
      ]"

      ph_rule "${room} On, Dark 2, Night" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_status ${lightlevel} gt 205),
        $(ph_condition_flag ${night})
      ]" "[
        $(ph_action_scene_recall ${group} ${nightmode})
      ]"
    else
      # lightlevel is Daylight sensor on Hue bridge
      ph_rule "${room} On, Daylight" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_daylight ${lightlevel})
      ]" "[
        $(ph_action_group_on ${group} false)
      ]"

      ph_rule "${room} On, Not Daylight, Day" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_daylight ${lightlevel} false),
        $(ph_condition_flag ${night} false)
      ]" "[
        $(ph_action_scene_recall ${group} ${default})
      ]"

      ph_rule "${room} On, Not Daylight, Night" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_daylight ${lightlevel} false),
        $(ph_condition_flag ${night})
      ]" "[
        $(ph_action_scene_recall ${group} ${nightmode})
      ]"
    fi
  else
    # lightlevel is a ZHALightLevel sensor
    ph_rule "${room} On, Daylight" "[
      $(ph_condition_flag ${flag}),
      $(ph_condition_daylight ${lightlevel})
    ]" "[
      $(ph_action_group_on ${group} false)
    ]"

    if [ -z "${8}" ] ; then
      ph_rule "${room} On, Dark, Day" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_dark ${lightlevel}),
        $(ph_condition_flag ${night} false)
      ]" "[
        $(ph_action_scene_recall ${group} ${default})
      ]"
    else
      ph_rule "${room} On, TV Off, Dark, Day" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_status ${status} lt 4),
        $(ph_condition_dark ${lightlevel}),
        $(ph_condition_flag ${night} false)
      ]" "[
        $(ph_action_scene_recall ${group} ${default})
      ]"

      ph_rule "${room} On, TV On, Dark, Day" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_status ${status} 4),
        $(ph_condition_dark ${lightlevel}),
        $(ph_condition_flag ${night} false)
      ]" "[
        $(ph_action_scene_recall ${group} ${tv})
      ]"

      ph_rule "${room} On, TV On, Not Daylight, Day" "[
        $(ph_condition_flag ${flag}),
        $(ph_condition_status ${status} 4),
        $(ph_condition_dx ${status} status),
        $(ph_condition_daylight ${lightlevel} false),
        $(ph_condition_flag ${night} false)
      ]" "[
        $(ph_action_scene_recall ${group} ${tv})
      ]"
    fi

    ph_rule "${room} On, Dark, Night" "[
      $(ph_condition_flag ${flag}),
      $(ph_condition_dark ${lightlevel}),
      $(ph_condition_flag ${night})
    ]" "[
      $(ph_action_scene_recall ${group} ${nightmode})
    ]"

    ph_rule "${room} On, Not Daylight, Night" "[
      $(ph_condition_flag ${flag}),
      $(ph_condition_daylight ${lightlevel} false),
      $(ph_condition_flag ${night}),
      $(ph_condition_dx ${night} flag)
    ]" "[
      $(ph_action_scene_recall ${group} ${nightmode})
    ]"
  fi
}

# ===== Fan ====================================================================

# Usage: ph_rules_fan room flag fan temperature
function ph_rules_fan() {
  local room="${1}"
  local -i flag=${2}
  local -i fan=${3}
  local -i temperature=${4}

  ph_rule "${room} Off" "[
    $(ph_condition_flag ${flag} false)
  ]" "[
    $(ph_action_light_on ${fan} false)
  ]"

  ph_rule "${room} Cool" "[
    $(ph_condition_temperature ${temperature} lt 2250)
  ]" "[
    $(ph_action_light_on ${fan} false)
  ]"

  ph_rule "${room} Hot" "[
    $(ph_condition_flag ${flag}),
    $(ph_condition_temperature ${temperature} gt 2300)
  ]" "[
    $(ph_action_light_on ${fan})
  ]"
}

# ===== Curtains ===============================================================

# TODO:
# - Change way of detecting room is too hot because of sun shining into it;
# - Prevent motion sensor from turning on room when curtains close.  Probably
#   need an additional status or flag for that.

# Usage: ph_rules_curtains room status curtains temperature [daylight]
function ph_rules_curtains() {
  local room="${1}"
  local -i status=${2}
  local -i curtains=${3}
  local -i temperature=${4}
  local -i daylight="${5:-1}"

  ph_rule "${room} Sunset" "[
    $(ph_condition_dark ${daylight})
  ]" "[
    $(ph_action_light_open ${curtains} false),
    $(ph_action_group_open ${curtains} false)
  ]"

  ph_rule "${room} Sunrise" "[
    $(ph_condition_status ${status} gt -1),
    $(ph_condition_daylight ${daylight}),
    $(ph_condition_localtime "23:00:00" "13:00:00")
  ]" "[
    $(ph_action_light_open ${curtains}),
    $(ph_action_group_open ${curtains})
  ]"

  # TODO: change time to lightlevel when sun shines into room
  ph_rule "${room} Cool, Daylight" "[
    $(ph_condition_temperature ${temperature} lt 2250),
    $(ph_condition_daylight ${daylight}),
    $(ph_condition_localtime "13:00:00" "23:00:00")
  ]" "[
    $(ph_action_light_open ${curtains}),
    $(ph_action_group_open ${curtains})
  ]"

  # TODO: change time to lightlevel when sun shines into room
  ph_rule "${room} Hot, Daylight" "[
    $(ph_condition_temperature ${temperature} gt 2300),
    $(ph_condition_daylight ${daylight}),
    $(ph_condition_localtime "13:00:00" "23:00:00")
  ]" "[
    $(ph_action_light_open ${curtains} false),
    $(ph_action_group_open ${curtains} false)
  ]"
}

# ===== Thermostat =============================================================

# Usage: ph_rules_thermo_display room thermostat
function ph_rules_thermo_display() {
  local room="${1}"
  local -i thermostat=${2}

  ph_rule "${room} Thermostat Display" "[
    $(ph_condition_sensor_config ${thermostat} displayflipped false)
  ]" "[
    $(ph_action_sensor_config ${thermostat} '{"displayflipped": true}')
  ]"
}

# Usage: ph_rules_thermo_home room thermostat flag [high [low]]
function ph_rules_thermo_home() {
  local room="${1}"
  local -i thermostat=${2}
  local -i flag=${3}
  local -i high=${4:-2100}
  local -i low=${5:-1500}

  ph_rule "${room} Away" "[
    $(ph_condition_flag ${flag} false),
    $(ph_condition_ddx ${flag} "00:05:00")
  ]" "[
    $(ph_action_heatsetpoint ${thermostat} ${low})
  ]"

  ph_rule "${room} Home" "[
    $(ph_condition_flag ${flag}),
    $(ph_condition_ddx ${flag} "00:05:00")
  ]" "[
    $(ph_action_heatsetpoint ${thermostat} ${high})
  ]"
}

# Usage: ph_rules_thermo_day room thermostat flag status [high [low]]
function ph_rules_thermo_day() {
  local room="${1}"
  local -i thermostat=${2}
  local -i night=${3}
  local -i status=${4}
  local -i high=${5:-2100}
  local -i low=${6:-1500}

  ph_rule "${room} Night On" "[
    $(ph_condition_flag ${night}),
    $(ph_condition_ddx ${night} "00:05:00")
  ]" "[
    $(ph_action_heatsetpoint ${thermostat} ${low})
  ]"

  ph_rule "${room} Wakeup 3/3" "[
    $(ph_condition_status ${status} -2),
    $(ph_condition_ddx ${status} status "00:10:00")
  ]" "[
    $(ph_action_heatsetpoint ${thermostat} ${high})
  ]"
}

# Usage: ph_rules_thermo_night room thermostat [high [low]]
function ph_rules_thermo_night() {
  local room="${1}"
  local -i thermostat=${2}
  local -i high=${3:-2100}
  local -i low=${4:-1500}

  ph_rule "${room} Night On, Week" "[
    $(ph_condition_config localtime in "W120/T21:00:00/T08:00:00")
  ]" "[
    $(ph_action_heatsetpoint ${thermostat} ${high})
  ]"

  ph_rule "${room} Night Off, Week" "[
    $(ph_condition_config localtime in "W120/T08:00:00/T21:00:00")
  ]" "[
    $(ph_action_heatsetpoint ${thermostat} ${low})
  ]"

  ph_rule "${room} Night On, Weekend" "[
    $(ph_condition_config localtime in "W7/T21:00:00/T09:00:00")
  ]" "[
    $(ph_action_heatsetpoint ${thermostat} ${high})
  ]"

  ph_rule "${room} Night Off, Weekend" "[
    $(ph_condition_config localtime in "W7/T09:00:00/T21:00:00")
  ]" "[
    $(ph_action_heatsetpoint ${thermostat} ${low})
  ]"
}
