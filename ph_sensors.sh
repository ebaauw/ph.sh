#!/bin/bash
#
# ph_sensors.sh
# Copyright © 2017 Erik Baauw. All rights reserved.
#
# Create/configure sensors on the Hue bridge or deCONZ gateway.
# Note: be sure to re-create rules after re-creating sensors.

# ===== SENSOR ID ==============================================================

# To force (re-)creation of sensors with a pre-determined resource id, we create
# dummy sensor resources to fill up all the sensor resource slots.  Before
# creating a CLIP sensor, we delete the dummy sensor for the id we want the CLIP
# sensor to have.
#
# The same approach works for adding ZigBee sensors to the Hue bridge.  Before
# searching for a new sensor, we delete the dummy sensor for the id we want the
# ZigBee sensor to have.
# The Hue motion sensor requires special attention, since it uses three
# resources.  The following steps add a Hue Motion sensor with id xx for the
# ZLLPresence resource, yy for ZLLLightLevel, and zz for ZLLTemperature:
# - ph_sensors_init
# - ph_delete /sensors/zz (temperature)
# - ph_post /sensors
# - reset motion sensor
# - ph_delete /sensors/xx (presence)
# - ph_delete /sensors/yy (lightlevel)
# - ph_post /sensors
#
# For adding ZigBee sensors to deCONZ, it's probably easier just to let deCONZ
# assign sensor resource IDs, shutdown deCONZ and change the sensor IDs in the
# deCONZ database (in ~/.local/share/dresden-elektronik/deCONZ/zll.db).  I use
# sqlitebrowser for that.

# Create dummy sensors.
function ph_sensors_init() {
  local -i id

  [ "${_ph_model}" == "deCONZ" ] && ph_restart

  # Clear names of existing sensors.
  for id in $(ph_json_args=-al ph_get /sensors |
              grep /name: | cut -d / -f 2) ; do
    [ "${_ph_model}" != "deCONZ" -a ${id} -eq 1 ] && continue
    ph_put "/sensors/${id}" '{
      "name": "_dummy"
    }'
    _ph_info "/sensors/${id}: turned to dummy sensor"
  done

  # Create dummy sensors for unused sensor slots.
  while true ; do
    id=$(ph_post /sensors '{
      "name": "_dummy",
      "type": "CLIPGenericFlag",
      "modelid": "_dummy",
      "manufacturername": "_dummy",
      "swversion": "0",
      "uniqueid": "_dummy"
    }' 2>/dev/null)
    [ $? -eq 0 ] || break
    _ph_info "/sensors/${id}: created dummy sensor"
  done

  # Delete existing Hue motion sensor resoucelinks.
  for id in $(ph_json_args=-al ph_get /resourcelinks |
              grep /classid:10010 | cut -d / -f 2) ; do
    ph_delete "/resourcelinks/${id}"
    _ph_info "/resourcelinks/${id}: deleted"
  done
}

# Remove dummy sensors.
function ph_sensors_cleanup() {
  local -i id
  for id in $(ph_json_args=-al ph_get /sensors |
              grep /name:\"_dummy\" | cut -d / -f 2) ; do
    ph_delete "/sensors/${id}"
    _ph_info "/sensors/${id}: deleted dummy sensor"
  done
  [ "${_ph_model}" == "deCONZ" ] && ph_restart
}

# ===== CLIP SENSORS ===========================================================

# Create CLIP sensor.
# Usage: id=$(_ph_sensor_clip id mid name type [swversion])
function _ph_sensor_clip()
{
  ph_delete "/sensors/${1}" >/dev/null 2>&1
  [ "${_ph_model}" == "deCONZ" ] && ph_restart
  id=$(ph_post "/sensors" "{
    \"name\": \"${3}\",
    \"type\": \"${4}\",
    \"modelid\": \"${4}\",
    \"manufacturername\": \"homebridge-hue\",
    \"swversion\": \"${5:-0}\",
    \"uniqueid\": \"/sensors/${2}${2:+-}${1}\"
  }")
  [ $? -ne 0 ] && return 1
  _ph_info "/sensors/${id}: ${4} \"${3}\""
  [ ${id} -ne ${1} ] && _ph_warn "/sensors/${id}: not requested id ${1}"
  echo ${id}
}

# Create CLIPGenericFlag sensor.
# Usage: id=$(ph_sensor_clip_flag id mid name [readonly])
function ph_sensor_clip_flag() {
  _ph_sensor_clip "${1}" "${2}" "${3}" CLIPGenericFlag "${4:+1}"
}

# Create CLIPGenericStatus sensor.
# Usage: ph_sensor_clip_status id mid name [min max]]
function ph_sensor_clip_status() {
  _ph_sensor_clip "${1}" "${2}" "${3}" CLIPGenericStatus "${4:-0},${5:-2}"
}

# Create CLIPPresence sensor.
# Usage: ph_sensor_clip_presence id mid name
function ph_sensor_clip_presence() {
  _ph_sensor_clip "${1}" "${2}" "${3}" CLIPPresence
}

# Create CLIPLightLevel sensor.
# Usage: ph_sensor_clip_lightlevel id name
function ph_sensor_clip_lightlevel() {
  _ph_sensor_clip "${1}" "${2}" "${3}" CLIPLightLevel
}

# Create CLIPTemperature sensor.
# Usage: ph_sensor_clip_temperature id name
function ph_sensor_clip_temperature() {
  _ph_sensor_clip "${1}" "${2}" "${3}" CLIPTemperature
}

# Create CLIPHumidity sensor.
# Usage: ph_sensor_clip_humidity id name
function ph_sensor_clip_humidity() {
  _ph_sensor_clip "${1}" "${2}" "${3}" CLIPHumidity
}

# Create CLIPPressure sensor.
# Usage: ph_sensor_clip_pressure id name
function ph_sensor_clip_pressure() {
  _ph_sensor_clip "${1}" "${2}" "${3}" CLIPPressure
}

# Create CLIPOpenClose sensor.
# Usage: ph_sensor_clip_pressure id name
function ph_sensor_clip_openclose() {
  _ph_sensor_clip "${1}" "${2}" "${3}" CLIPOpenClose
}

# ===== ZIGBEE SENSORS =========================================================

# Set sensor name.
# Usage: ph_sensor_name id name
function ph_sensor_name() {
  ph_put "/sensors/${1}" "{
    \"name\": \"${2}\"
  }"
  [ $? -eq 0 ] || return 1
  local type="$(ph_unquote "$(ph_get "/sensors/${1}/type")")"
  _ph_info "/sensors/${id}: ${type} \"${2}\""
}

# Set Hue Motion presence sensor name, sensitivity, and resourcelink.
# Hue app v2 expects a resourcelink before it shows Hue Motion status.
# Usage: ph_sensor_presence id name [sensitivity]
function ph_sensor_presence() {
  ph_sensor_name "${1}" "${2}"
  [ $? -ne 0 ] && return 1
  ph_put "/sensors/${1}/config" "{
    \"sensitivity\": ${3:-2}
  }"
  [ $? -eq 0 ] || return 1
  if [ "${_ph_model}" != "deCONZ" ] ; then
    id=$(ph_post /resourcelinks "{
      \"name\": \"${2}\",
      \"type\": \"Link\",
      \"classid\": 10010,
      \"links\": [ \"/sensors/${1}\" ]
    }")
    _ph_info "/resourcelinks/${id}: ${2}"
  fi
}

# Set Hue Motion lightlevel sensor name and thresholds.
# Usage: ph_sensor_lightlevel id name [tholddark tholdoffset]
function ph_sensor_lightlevel() {
  ph_sensor_name "${1}" "${2}"
  [ $? -eq 0 ] || return 1
  ph_put "/sensors/${1}/config" "{
    \"tholddark\": ${3:-12000},
    \"tholdoffset\": ${4:-4000}
  }"
}
