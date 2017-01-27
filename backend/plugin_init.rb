require 'fileutils'
require 'tmpdir'

# require files from lib
Dir.glob(File.join(File.dirname(__FILE__), "lib", "*.rb")).sort.each do |file|
  require File.absolute_path(file)
end

unless AppConfig.has_key?(:aspace_exporter)
  AppConfig[:aspace_exporter] = {
    on_startup: true,
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
  }
end

config         = AppConfig[:aspace_exporter]
file_extension = ".xml"
pdf            = false

if config[:method][:name].to_s =~ /pdf/
  file_extension = ".pdf"
  pdf            = true
end

if config[:on_startup]
  FileUtils.mkdir_p(config[:output_directory])
  $stdout.puts "\n\n\n\n\nExporting records from ArchivesSpace: #{Time.now}\n\n\n\n\n"

  exporter = ArchivesSpace::Exporter.new(config[:model], config[:method], config[:opts])
  exporter.export do |record, id|
    output_filename = "repository_#{config[:opts][:repo_id].to_s}_#{config[:model].to_s}_#{id.to_s}#{file_extension}"
    output_path     = File.join(config[:output_directory], output_filename)
    if pdf
      FileUtils.cp record, output_path
    else
      IO.write output_path, record
    end
    $stdout.puts "Exported: #{id.to_s}"
  end

  $stdout.puts "\n\n\n\n\nExport complete: #{Time.now}\n\n\n\n\n"
end
