# ph.sh

## Shell commands for Philips Hue
Copyright © 2017 Erik Baauw. All rights reserved.

This `bash` script provides basic shell commands for interacting with a [Philips Hue](http://www2.meethue.com/) bridge, using the Philips Hue [API](https://developers.meethue.com/philips-hue-api).  These shell commands can be used to interact manually with the bridge, instead of the CLIP API debugger (see [Getting Started](https://developers.meethue.com/documentation/getting-started)).  They can also be used in other scripts to (re-)create your entire bridge configuration.

These shell commands might also be used for interacting with other bridges that provide a compatible API.  In particular, they work for with the dresden elektronik [deCONZ REST API](http://dresden-elektronik.github.io/deconz-rest-doc/) (except where noted).

### Commands
The following commands are provided by `ph.sh`:

Command | Description
-------- | -----------
`ph_get` _path_ | Retrieves _path_ from the bridge. <br>Resources as well as resource attributes can be specified as _path_. <br>The formatted response is written to the standard output.
`ph_put` _resource_ _body_ | Updates _resource_ on the bridge.
`ph_patch` _resource_ _body_ | Updates _resource_ on the bridge. <br>Not supported by Philips Hue bridges.
`ph_post` _resource_ _body_ | Creates _resource_ on the bridge. <br>The ID of the resource created is written to the standard output.
`ph_delete` _resource_ | Deletes _resource_ from the bridge.
`ph_linkbutton` | Simulates pressing the link button on the bridge, to allow an application to register. <br>Not currently supported by deCONZ bridges.
`ph_createuser` | Register `ph.sh` on the bridge. <br>The username created by the bridge is written to the standard output.
`ph_touchlink` | Initiate a touchlink on the bridge. <br>Not currently supported by deCONZ bridges.
`ph_reset_homekit` | Reset the HomeKit configuration for a v2 (square) Philips Hue bridge.
`ph_findhost` | Find the first registered bridge on the meethue or dresden elektronik portal. <br>The host is written to the standard output.
`ph_nupnp` | Query the meethue portal for registered Philips Hue bridges. <br>The formatted response is written to the standard output.
`ph_nupnp_deconz` | Query the dresden elektronik portal for registered deCONZ bridges. <br>The formatted response is written to the standard output.
`ph_description` | Retrieve the bridge device description in XML.
`ph_config` | Retrieve the bridge configuration using an unauthorised request. <br>The formatted response is written to the standard output. <br>Not currently supported by deCONZ bridges.

These commands depend on `curl`, to send HTTP requests to the bridge, and on `json`, to format the bridge responses into human readable or machine readable output.  A `bash` implementation of `json` is provided by `json.sh`.  See `json -h` for its usage.

### Configuation
The following shell variables are used by `ph.sh`:

Variable | Default | Description
-------- | -------| -----------
`ph_host` | _discovered_ | The hostname or IP address (and port) of the bridge. <br>Set to the first bridge registered on the meethue or dresden elektronik portal, when not set while loading `ph.sh`.
`ph_username` | _empty_ | The username on the bridge used to authenticate requests. <br>You can create a username using `ph_createuser`.
`ph_debug` | `false` | When set to `true`, issue debug messages to standard error for requests sent to and responses received from the bridge.

### Installation
To install, take the following steps:
- Copy `ph.sh` and `json.sh` to a directory in your `$PATH`, e.g. `~/bin` or `/usr/local/bin`;
- Load the commands by issuing `. ph.sh` from the command line;
- Check that your bridge can be reached by issuing `ph_config` from the command line;
- Create a username by issuing `ph_createuser` from the command line;
- Include the following lines in your `.bashrc`:
```sh
ph_username=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
. ph.sh
```

### Caveats
I'm running `ph.sh` on my Apple Mac computers and on my Raspberry Pi, but it should work on any recent Linux or Unix system with `bash`.

While functional, the `bash` implementation of `json` is not very efficient, especially for large JSON responses.  Formatting the full bridge state for `ph_get /` takes 1m24s on my RaspPi (and 23s on my Mac).  When I use a binary implementation of `json` instead, it takes less than 2s on my Mac.  However, I've written this implementation in Swift, and I haven't ported it to other platforms.  I should probably have created a NodeJS implementation...

### Examples
Here are some examples how to use interactively the commands provided by `ph.sh`:

- Create a username and store it in the `ph_username` variable:
  ```bash
  ph_username=$(ph_createuser)
  ```
- Switch off all lights:
  ```bash
  ph_put /groups/0/action '{"on":false}'
  ```
- Check whether light `1` is on:
  ```bash
  ph_get /lights/1/state/on
  ```
  The output is the value of the `state.on` attribute:
  ```json
  false
  ```
  Note that the Hue API doesn't allow a `GET` on `/lights/1/state/on`.  Internally, `ph_get` does the equivalent of:
  ```bash
  ph_get /lights/1 | json -p /state/on
  ```
- Get the state of light `1`:
  ```bash
  ph_get /lights/1/state
  ```
  The output is formatted for human readability:
  ```json
  {
    "on": false,
    "bri": 254,
    "hue": 13195,
    "sat": 210,
    "effect": "none",
    "xy": [
      0.5106,
      0.415
    ],
    "ct": 463,
    "alert": "none",
    "colormode": "xy",
    "reachable": true
  }
  ```
- Create a group:
  ```bash
  ph_post /groups '{"name": "My Group", "lights": ["1", "2", "3"]}'
  ```
  The output is the id of the newly created group:
  ```json
  2
  ```
  Delete the group we just created:
  ```bash
  ph_delete /groups/2
  ```

### Advanced Examples
Here are some examples how to use the commands provided by `ph.sh` in scripting:

- Use `json -al` to get text output, for further processing with with the likes of `grep` and `cut`:
  ```bash
  ph_get /lights/1/state | json -al
  ```
  This outputs:
  ```bash
  /on:false
  /bri:254
  /hue:13195
  /sat:210
  /effect:"none"
  /xy/0:0.5106
  /xy/1:0.415
  /ct:463
  /alert:"none"
  /colormode:"xy"
  /reachable:true
  ```
- Check for non-reachable lights
  ```bash
  ph_get /lights | json -al | grep /reachable:false | cut -d / -f 2
  ```
  The output contains the ids of the lights for which the `state.reachable` attribute is `false`:
  ```json
  11
  36
  ```
  To see the names of these lights rather than their numbers, use:
  ```bash
  for light in $(ph_get /lights | json -al | grep /reachable:false | cut -d / -f 2) ; do
    ph_get /lights/${light}/name
  done
  ```
- Delete the rules created by the Philips Hue app:
  ```bash
  for user in $(ph_get /config/whitelist | json -al | grep /name:\"hue_ios_app# | cut -d / -f 2) ; do
    for rule in $(ph_get /rules | json -al | grep "/owner:\"${user}\"" | cut -d / -f 2) ; do
      ph_delete "/rules/${rule}"
    done
  done
  ```
