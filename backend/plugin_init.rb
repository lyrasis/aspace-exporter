require 'fileutils'
require 'tmpdir'

# require files from lib
Dir.glob(File.join(File.dirname(__FILE__), "lib", "*.rb")).sort.each do |file|
  require File.absolute_path(file)
end

unless AppConfig.has_key?(:aspace_exporter)
  AppConfig[:aspace_exporter] = [{
    name: :ead_xml,
    schedule: "0",
    output_directory: File.join(Dir.tmpdir, "exports"),
    location: AppConfig[:backend_url],
    method: {
      # name: :generate_pdf_from_ead, # for pdf export
      name: :generate_ead,
      args: [false, true, true, false],
    },
  }]
end

ArchivesSpaceService.loaded_hook do
  AppConfig[:aspace_exporter].each do |config|
    unless AppConfig[:plugins].include? "resource_updates"
      $stderr.puts "Export on update requires resource_updates plugin!"
      next
    end
    # enforced defaults
    schedule       = config[:schedule].strip.concat(" * * * *")
    config[:model] = :resource
    config[:opts]  = {}

    # check for updates and export (wouldn't recommend < 1hr interval)
    ArchivesSpaceService.settings.scheduler.cron(
      schedule, :tags => "aspace-exporter-update-#{config[:name]}"
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
          config[:location],
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
        data     = CSV.foreach(manifest, headers: true).select { |row| row[2] == update[:uri] }.first
        next unless data
        filename           = data["filename"]
        data["updated_at"] = Time.now.to_s # update modified time
        data["deleted"]    = true          # set deleted true
        ArchivesSpace::Exporter.update_manifest(manifest, data.values)
        ArchivesSpace::Exporter.delete_file(config[:output_directory], filename)
      end
    end
  end
end
