# aspace-exporter

Efficiently export records from ArchivesSpace.

## Setup

This plugin by default is configured to require [resource_updates](https://github.com/lyrasis/resource_updates).

```
AppConfig[:plugins] << "resource_updates" # must come before exporter
AppConfig[:plugins] << "aspace-exporter"
```

Modify the `AppConfig[:aspace_exporter]` configuration if necessary.

## What it does

It exports records to an output directory. There are multiple options:

### On startup

Records will be immediately exported from ArchivesSpace. This will
delay application startup time so do this only as needed.

### On schedule

Exports can be configured to run on a schedule using the cron format.

### On updates

Every hour check for and export updated records. This depends on the
[resource_updates](https://github.com/lyrasis/resource_updates) plugin.

It will also remove files for records that were deleted.

Note: __only resource record updates are supported with this option__.

Minimal configuration for EAD XML exports on update:

```
AppConfig[:aspace_exporter] = [{
  name: :ead_xml,
  on: {
    update: true,
  },
  output_directory: "/opt/archivesspace/exports",
  model: :resource,
  method: {
    name: :generate_ead,
    args: [false, true, true],
  },
}]
```

## Compatibility

ArchivesSpace versions tested (non-release versions may become incompatible):

- v1.5.3
- v2.0.1 (release)

## License

This plugin is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

---
