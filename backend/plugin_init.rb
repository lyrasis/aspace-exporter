require 'fileutils'
require 'tmpdir'

# require files from lib
Dir.glob(File.join(File.dirname(__FILE__), "lib", "*.rb")).sort.each do |file|
  require File.absolute_path(file)
end

unless AppConfig.has_key?(:aspace_exporter)
  AppConfig[:aspace_exporter] = [{
    name: :ead_xml,
    on: {
      startup: false,
      update: false,
      schedule: false,
    },
    # schedule: "0 * * * *", # cron for on update
    schedule: "0 22 * * *", # cron for on schedule
    output_directory: File.join(Dir.tmpdir, "exports"),
    model: :resource,
    method: {
      # name: :generate_pdf_from_ead, # for pdf export
      name: :generate_ead,
      args: [false, true, true, false],
    },
    # opts limits the scope for on startup and schedule
    # (and repo_id is required for them)
    # but does not limit scope for update: true
    opts: {
      repo_id: 2,
      # id: 48,
    },
  }]
end

ArchivesSpaceService.loaded_hook do
  AppConfig[:aspace_exporter].each do |config|
    exporter_config = ArchivesSpace::Exporter::Config.new(
      config[:name],
      config[:model],
      config[:method],
      config[:opts],
      config[:output_directory],
    )

    if config[:on][:startup]
      # do it now!
      ArchivesSpace::Exporter.export(exporter_config)
    end

    if config[:on][:schedule] and config.has_key? :schedule
      # do it later =)
      ArchivesSpaceService.settings.scheduler.cron(
        config[:schedule], :tags => "aspace-exporter-schedule-#{config[:name]}"
      ) do
          ArchivesSpace::Exporter.export(exporter_config)
      end
    end

    if config[:on][:update] and config[:model] == :resource # resources only
      # do it as records are modified ...
      unless AppConfig[:plugins].include? "resource_updates"
        $stderr.puts "Export on update requires resource_updates plugin!"
        next
      end
      # check for updates and export (wouldn't recommend < 1hr interval)
      ArchivesSpaceService.settings.scheduler.cron(
        config[:schedule], :tags => "aspace-exporter-update-#{config[:name]}"
      ) do
        current_time   = Time.now.utc
        modified_since = (current_time - 3600)
        $stdout.puts "Checking for resource updates between: #{modified_since} [#{modified_since.to_i}] and #{current_time} [#{current_time.to_i}]"
        updates = ArchivesSpace::ResourceUpdate.updates_since(modified_since.to_i)
        updates[:updated].each do |update|
          updater_config = ArchivesSpace::Exporter::Config.new(
            config[:name],
            config[:model],
            config[:method],
            config[:opts],
            config[:output_directory],
          )
          # "/repositories/2/resources/1", ["", "repositories", "2", "resources", "1"]
          _, _, repo_id, _, id = update[:uri].split("/")
          updater_config.opts[:repo_id] = repo_id.to_i
          updater_config.opts[:id]      = id.to_i
          ArchivesSpace::Exporter.export(updater_config)
        end
        updates[:deleted].each do |update|
          # uri: "/repositories/2/resources/1"
          manifest = ArchivesSpace::Exporter.get_manifest_path config[:output_directory], config[:name]
          data     = CSV.foreach(manifest, headers: true).select { |row| row[2] == update[:uri] }
          next unless data.any?
          data[3]  = Time.now # update modified time
          data[4]  = true     # set deleted true
          ArchivesSpace::Exporter.update_manifest(manifest, data)
          ArchivesSpace::Exporter.delete_file(config[:output_directory], data[1])
        end
      end
    end
  end
end
