# aspace-exporter

Efficiently export records from ArchivesSpace.

## Setup

```
AppConfig[:plugins] << "archivesspace_export_service" # OPTIONAL
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
[archivesspace_export_service](https://github.com/hudmol/archivesspace_export_service) plugin.

It will also remove files for records that were deleted.

Note: __only resource record updates are supported with this option__.

## Compatibility

ArchivesSpace versions tested:

- v1.5.3

## License

This plugin is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

---
