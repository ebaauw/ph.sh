# ph.sh

## Shell commands for Philips Hue
Copyright © 2017 Erik Baauw. All rights reserved.

This shell script provides commands for interacting manually with the [Philips Hue](http://www2.meethue.com/) bridge using the [Philips Hue API](https://developers.meethue.com/philips-hue-api).

### Commands

Command | Description
-------- | -----------
`ph_get` _resource_ | Retrieves _resource_ from the bridge.  The formatted response is written to the standard output.
`ph_put` _resource_ _body_ | Updates _resource_ on the bridge.
`ph_post` _resource_ _body_ | Creates _resource_ on the bridge.  The ID of the resource is written to the standard output.
`ph_delete` _resource_ | Deletes _resource_ from the bridge.
`ph_linkbutton` | Simulates pressing the link button on the bridge, to allow an application to create a username.
`ph_createuser` | Create a username for `ph.sh`.  The username is written to the standard output.
`ph_touchlink` | Initiate a touchlink on the Hue bridge.
`ph_reset_homekit` | Reset the HomeKit configuration for a v2 (square) Hue bridge
`ph_nupnp` | Query the meethue portal for registered bridges.  The formatted response is written to the standard output.
`ph_nupnp_deconz` | Query the dresden elektronik portal for registered deCONZ virtual bridges.  The formatted response is written to the standard output.
`ph_description` | Retrieve the bridge device description in XML
`ph_config` | Retrieve the bridge configuration using an unauthorised request.  The formatted response is written to the standard output.

### Configuation

Variable | Default | Description
-------- | -------| -----------
`ph_host` | _discovered_ | Hostname or IP address of the Hue bridge.  When not specified, the meethue portal is queried and the first bridge registered is used.
`ph_username` | _empty_ | Username of the Hue bridge.  You can create a username using `ph_createuser`.
`ph_verbose` | `false` | When set to `true`, write the formatted bridge response to standard output for `ph_put`, `ph_post`, and `ph_delete`.
`ph_debug` | `false` | When set to `true`, issue debug messages to standard error for requests sent to and responses received from the Hue bridge.

### Installation

- Copy `ph.sh` and `json.sh` to a directory in your `$PATH`, e.g. `~/bin` or `/usr/local/bin`;
- Load the functions by issuing `. ph.sh` from the command line;
- Check that your bridge can be reached by issuing `ph_config` from the command line;
- Create a username by issuing `ph_createuser` from the command line;
- Include the following lines in your `.profile` or `.bashrc`:
```sh
ph_username=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
. ph.sh
```
