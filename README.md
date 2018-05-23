# aspace-exporter

Export resource records from ArchivesSpace.

## Setup

This plugin by default is configured to require [resource_updates](https://github.com/lyrasis/resource_updates).

```ruby
AppConfig[:plugins] << "resource_updates" # must come before exporter
AppConfig[:plugins] << "aspace-exporter"
```

Modify the `AppConfig[:aspace_exporter]` configuration if necessary.

## What it does

It exports records to an output directory with a manifest (a list of records with
some minimal metadata).

- location
- filename
- uri
- updated_at
- deleted

### How it works

Every hour it checks for and exports updated records. This depends on the
[resource_updates](https://github.com/lyrasis/resource_updates) plugin.

It will also remove files for records that were deleted.

```ruby
AppConfig[:aspace_exporter] = [{
  name: :ead_xml,
  schedule: "0", # the minute to check for updates once an hour
  output_directory: "/opt/archivesspace/exports",
  # url directory for the manifest
  location: "#{AppConfig[:backend_url]}/aspace_exporter/ead_xml/files",
  method: {
    name: :generate_ead,
    args: [false, true, true, false],
  },
}]
```

## API access

A new endpoint is available for retrieving the exported files over http(s):

```bash
curl -H "Accept: text/csv" \
  http://$host:$port/aspace_exporter/:name/manifest.csv

curl -H "Accept: application/xml" \
  http://$host:$port/aspace_exporter/:name/files/:filename

curl -H "Accept: application/pdf" \
  http://$host:$port/aspace_exporter/:name/files/:filename -o :filename
```

**Warning:** no permissions are required for these endpoints so be sure to protect
access to the api if exporting unpublished records.

## Compatibility

ArchivesSpace versions tested (non-release versions may become incompatible):

- v1.5.3
- v2.0.1
- v2.3.2

## License

This plugin is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

---
