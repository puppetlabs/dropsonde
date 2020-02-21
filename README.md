# Dropsonde

A simple telemetry probe for gathering information about Puppet infrastructures.

## Overview

Dropsonde is a simple telemetry probe designed to run as a regular cron job. It
will gather metrics defined by self-contained plugins that each defines its own
partial schema and then gathers the data to meet that schema.

Metrics plugins live in the `lib/dropsonde/metrics` directory. See the existing
examples for the API. All data returned must match the schema the plugin defines
and each column in the schema must be documented.

Dropsonde maintains a cache listing all the public modules existing on the Forge.
This is used for identifying public vs. private modules. Once a week, this cache
of modules is updated.


## Installation

This is distributed as a Ruby gem. Simply `gem install dropsonde`


## Configuration

Any command line arguments can also be specified in `~/.config/dropsonde.rc`.
For example the config file below will disable Forge module cache updating and
will not report the `:puppetfiles` metrics.


``` yaml
---
:update: false
:blacklist:
  - puppetfiles
```


## Running

Run `dropsonde --help` to see usage information.

* `preview`
    * Generate and print out an example telemetry report in human readable form
    * Annotated with descriptions of each plugin and each metric gathered.
* `schema`
    * Generate and print out the complete combined schema.
* `list`
    * See a quick list of the available metrics and what they do.
* `submit`
    * Generate and submit a telemetry report. This will be exactly the same as
      the human readable form, just in JSON format.
* `update`
    * Once a week, the list of public modules on the Forge will be updated. This
      command will manually force that cache update to happen.


## Limitations

This is super early in development and has not yet been battle tested.


Contact
-------

community@puppet.com

