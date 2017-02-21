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
      update: false,
      schedule: true,
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
      model: config[:model],
      method: config[:method],
      opts: config[:opts],
      output: config[:output_directory],
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
      unless AppConfig[:plugins].include? "archivesspace_export_service"
        raise "Export on update requires archivesspace export service!"
      end
      # check for updates and export
      ArchivesSpaceService.settings.scheduler.cron(
        "0 * * * *", :tags => "aspace-exporter-update-#{config[:name]}"
      ) do
        monitor = ResourceUpdateMonitor.new
        updates = monitor.updates_since((Time.now - 3600).to_i)
        updates['adds'].each do |add|
          updater_config = ArchivesSpace::Exporter::Config.new(
            model: config[:model],
            method: config[:method],
            opts: config[:opts],
            output: config[:output_directory],
          )
          updater_config.opts[:repo_id] = add["repo_id"]
          updater_config.opts[:id]      = add["id"]
          ArchivesSpace::Exporter.export(updater_config)
        end
        updates['removes'].each do |id_to_remove|
          filename = ArchivesSpace::Exporter.filename_for(
            config[:name], "*", config[:model], id_to_remove
          )
          filename = config[:method][:name].to_s =~ /pdf/ ? "#{filename}.pdf" : "#{filename}.xml"
          Dir["#{config[:output_directory]}/#{filename}"].each { |f| FileUtils.rm(f) }
        end
      end
    end
  end
end