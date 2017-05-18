require 'fileutils'
require 'tmpdir'

# require files from lib
Dir.glob(File.join(File.dirname(__FILE__), "lib", "*.rb")).sort.each do |file|
  require File.absolute_path(file)
end

unless AppConfig.has_key?(:aspace_exporter)
  AppConfig[:aspace_exporter] = [{
    name: :default,
    on: {
      startup: false,
      update: true,
      schedule: false,
    },
    schedule: "0 22 * * *",
    output_directory: "#{Dir.tmpdir}/exports",
    model: :resource,
    method: {
      # name: :generate_pdf_from_ead,
      name: :generate_ead,
      args: [false, true, true],
    },
    # opts limit scope for on startup and schedule
    # but do not limit scope for update: true
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
        raise "Export on update requires resource_updates plugin!"
      end
      # check for updates and export (wouldn't recommend < 1hr interval)
      ArchivesSpaceService.settings.scheduler.cron(
        "0 * * * *", :tags => "aspace-exporter-update-#{config[:name]}"
      ) do
        updates = ArchivesSpace::ResourceUpdate.updates_since((Time.now - 3600).to_i)
        updates[:updated].each do |update|
          updater_config = ArchivesSpace::Exporter::Config.new(
            config[:name],
            config[:model],
            config[:method],
            config[:opts],
            config[:output_directory],
          )
          # "/repositories/2/resources/1", ["", "repositories", "2", "resources", "1"]
          uri_parts = update[:uri].split("/")
          updater_config.opts[:repo_id] = uri_parts[2]
          updater_config.opts[:id]      = uri_parts[4]
          ArchivesSpace::Exporter.export(updater_config)
        end
        updates[:deleted].each do |update|
          # "/repositories/2/resources/1", ["", "repositories", "2", "resources", "1"]
          uri_parts = update[:uri].split("/")
          filename = ArchivesSpace::Exporter.filename_for(
            config[:name], "*", config[:model], uri_parts[4]
          )
          filename = config[:method][:name].to_s =~ /pdf/ ? "#{filename}.pdf" : "#{filename}.xml"
          Dir["#{config[:output_directory]}/#{filename}"].each { |f| FileUtils.rm(f) }
        end
      end
    end
  end
end