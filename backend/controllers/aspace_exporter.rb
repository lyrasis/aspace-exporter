class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/aspace_exporter/:name/manifest/manifest.csv')
    .description("Retrieve an export manifest")
    .params(
      ["name", String, "The exporter profile name", required: true]
    )
    .permissions([])
    .returns([200, ""]) \
  do
    config   = get_exporter_config(params[:name])
    manifest = get_exporter_manifest(config)

    [200, {"Content-Type" => "text/csv"}, [File.read(manifest) + "\n"]]
  end

  Endpoint.get('/aspace_exporter/:name/file/:filename')
    .description("Retrieve an exported EAD")
    .params(
      ["name", String, "The exporter profile name", required: true],
      ["filename", String, "The resource filename", required: true],
      ["format", String, "The resource format", optional: true]
    )
    .permissions([])
    .returns([200, ""]) \
  do
    config   = get_exporter_config(params[:name])
    manifest = get_exporter_manifest(config)

    format   = params[:format] || "xml"
    data     = CSV.foreach(manifest, headers: true).select { |row| row[1] == params[:filename] }.first
    filename = data["filename"] if data
    file     = filename ? File.join(config[:output_directory], filename) : ""

    raise "Error exporting: #{params[:filename]}" unless File.file? file
    # TODO: other response types
    stream_response(Nokogiri.XML(File.open(file), nil, 'UTF-8').to_xml)
  end

  private

  def get_exporter_config(name)
    config = AppConfig[:aspace_exporter].find { |e| e[:name].to_s == params[:name] }
    raise "Unable to find exporter config for #{params[:name]}" unless config
    config
  end

  def get_exporter_manifest(config)
    manifest = ArchivesSpace::Exporter.get_manifest_path config[:output_directory], config[:name]
    raise "Unable to find exporter manifest for #{params[:name]}" unless File.file? manifest
    manifest
  end

end
