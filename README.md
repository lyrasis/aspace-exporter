# aspace-exporter

Export records from ArchivesSpace on startup and / or on a schedule.

## Setup

```
AppConfig[:plugins] << "aspace-exporter"
```

Modify the `AppConfig[:aspace_exporter]` configuration if necessary. By
default the exporter will export resources as EAD from repository 2 to
the system temporary directory (in a folder called exports).

## What it does

If the configuration is set to export on startup (which is the default)
then records will be immediately exported from ArchivesSpace. This will
delay application startup time so set `on_startup` to false to prevent
this.

It's also possible to configure exports to run on a schedule using the
cron format.

## Compatibility

ArchivesSpace versions tested:

- v1.5.3

## License

This plugin is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

---
