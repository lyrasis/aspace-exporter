# aspace-exporter

Export records from ArchivesSpace.

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
delay application starup time so set `on_startup` to false or disable
the plugin when exporting is not required.

## TODO

Add an endpoint that can run export in background? Integrate with jobs?

## License

This plugin is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

---