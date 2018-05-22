class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/aspace_exporter/:name')
    .description("Retrieve an exported EAD")
    .params(
      ["name", String, "The exporter profile name", required: true],
      ["uri", String, "The resource uri", required: true],
      ["format", String, "The resource format", optional: true]
    )
    .permissions([])
    .returns([200, ""]) \
  do
    config = AppConfig[:aspace_exporter].find { |e| e[:name].to_s == params[:name] }
    format = params[:format] || "xml"
    raise "Unable to find exporter config for #{params[:name]}" unless config

    # uri: "/repositories/2/resources/1"
    manifest = ArchivesSpace::Exporter.get_manifest_path config[:output_directory], config[:name]
    data     = CSV.foreach(manifest, headers: false).select { |row| row[2] == params[:uri] }.first
    filename = data[1] if data
    file     = filename ? File.join(config[:output_directory], filename) : ""

    raise "Error exporting: #{params[:uri]}" unless File.file? file
    # TODO: other response types
    stream_response(Nokogiri.XML(File.open(file), nil, 'UTF-8').to_xml)
  end

end
