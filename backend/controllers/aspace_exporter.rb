class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/aspace_exporter/:name')
    .description("Retrieve an exported EAD (generate 1st if not exists)")
    .params(
      ["name", String, "The exporter profile name", required: true],
      ["uri", String, "The resource uri", required: true],
      ["format", String, "The resource format", optional: true],
      ["refresh", BooleanParam, "Regenerate record before retrieval", optional: true]
    )
    .permissions([:view_all_records])
    .returns([200, ""]) \
  do
    config = AppConfig[:aspace_exporter].find { |e| e[:name].to_s == params[:name] }
    format = params[:format] || "xml"
    raise "Unable to find exporter config for #{params[:name]}" unless config
    # "/repositories/2/resources/1", ["", "repositories", "2", "resources", "1"]
    _, _, repo_id, _, id = params[:uri].split("/")
    filename = ArchivesSpace::Exporter.filename_for(
      config[:name], repo_id, config[:model], id
    )
    file = File.join(config[:output_directory], "#{filename}.#{format}")
    if !File.file?(file) or params[:refresh]
      updater_config = ArchivesSpace::Exporter::Config.new(
        config[:name],
        config[:model],
        config[:method],
        config[:opts],
        config[:output_directory],
      )
      updater_config.opts[:repo_id] = repo_id.to_i
      updater_config.opts[:id]      = id.to_i
      ArchivesSpace::Exporter.export(updater_config)
    end

    raise "Error exporting #{filename}" unless File.file? file
    stream_response(Nokogiri.XML(File.open(file), nil, 'UTF-8').to_xml)
  end

end