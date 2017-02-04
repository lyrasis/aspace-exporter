require 'fileutils'
require 'tmpdir'

# require files from lib
Dir.glob(File.join(File.dirname(__FILE__), "lib", "*.rb")).sort.each do |file|
  require File.absolute_path(file)
end

unless AppConfig.has_key?(:aspace_exporter)
  AppConfig[:aspace_exporter] = [{
    on_startup: false,
    on_schedule: true,
    schedule: "0 22 * * *",
    # schedule: "* * * * *",
    output_directory: "#{Dir.tmpdir}/exports",
    model: :resource,
    method: {
      # name: :generate_pdf_from_ead,
      name: :generate_ead,
      args: [false, true, true],
    },
    opts: {
      repo_id: 2,
      # id: 48,
    },
  }]
end

ArchivesSpaceService.loaded_hook do
  AppConfig[:aspace_exporter].each_with_index do |config, idx|
    if config[:on_startup]
      # do it now!
      ArchivesSpace::Exporter.export(config)
    end

    if config[:on_schedule] and config.has_key? :schedule
      # do it later =)
      ArchivesSpaceService.settings.scheduler.cron(
        config[:schedule], :tags => "aspace-exporter-#{(idx + 1).to_s}"
      ) do
        ArchivesSpace::Exporter.export(config)
      end
    end
  end
end