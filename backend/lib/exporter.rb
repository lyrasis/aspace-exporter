module ArchivesSpace

  class Exporter

    include ExportHelpers
    include URIResolver

    Config = Struct.new(:name, :model, :method, :opts, :output, :location) do
      # name: default
      # model: resource
      # method: { name: generate_ead, args: [] }
      # opts: { repo_id: 2, id: nil }
      # output: "/tmp/exports"
      # location: "#{AppConfig[:frontend_proxy_url]}/api"
    end

    MANIFEST_HEADERS = ["location", "filename", "uri", "title", "updated_at", "deleted"]

    attr_reader :extension, :pdf

    def self.delete_file(output, filename)
      Dir[File.join(output, filename)].each { |f| FileUtils.rm(f) }
    end

    def self.export(config)
      FileUtils.mkdir_p(config.output)
      manifest = get_manifest_path(config.output, config[:name])
      update_manifest(manifest, MANIFEST_HEADERS) unless File.file? manifest

      $stdout.puts "Exporting records from ArchivesSpace: #{Time.now}"

      exporter = ArchivesSpace::Exporter.new(config)
      exporter.export do |record, id, filename, title|
        if record
          exporter.write(record, config.output, filename)
          $stdout.puts "Exported: #{id.to_s} as #{filename}"

          data = {
            location:   location_to(config.location, filename),
            filename:   filename,
            uri:        uri_for(config.opts[:repo_id], config.model, id),
            title:      title,
            updated_at: Time.now,
            deleted:    false,
          }
          $stdout.puts "Manifest: #{data.values.join(',')}"
          update_manifest(manifest, data.values)
        end
      end

      $stdout.puts "Export complete: #{Time.now}"
    end

    def self.find_in_manifest?(manifest, data)
      IO.foreach(manifest).grep(/#{Regexp.escape(data)}/).take(1).any? if File.file?(manifest)
    end

    def self.get_manifest_path(output, name)
      File.join(output, "manifest_#{name}.csv")
    end

    def self.location_to(url, filename)
      "#{url.chomp('/')}#{('/' + filename).squeeze('/')}"
    end

    def self.remove_stale_data(manifest, location)
      tmp = Tempfile.new
      begin
        File.foreach(manifest) do |line|
          tmp.puts line unless line.include?(location)
        end
        tmp.close
        FileUtils.mv(tmp.path, manifest)
      ensure
        tmp.close
        tmp.unlink
      end
    end

    def self.uri_for(repo_id, model, id)
      "/repositories/#{repo_id.to_s}/#{model.to_s}s/#{id.to_s}"
    end

    def self.update_manifest(manifest, data)
      if find_in_manifest?(manifest, data[0])
        remove_stale_data(manifest, data[0])
      end
      CSV.open(manifest, 'a') do |csv|
        csv << data
      end
      File.chmod(0644, manifest)
    end

    def initialize(config)
      @filename_field = filename_field_for(config.model)
      @model          = model_class_from_sym(config.model)
      @method         = config.method[:name]
      @args           = config.method[:args]
      @opts           = config.opts
      @repo_id        = config.opts[:repo_id]
      @pdf            = false
      @extension      = ".xml"

      # pdf isn't in line with the rest =(
      if @method == :generate_pdf_from_ead
        @method    = :generate_ead
        @pdf       = true
        @extension = ".pdf"
      end
    end

    def export
      RequestContext.open(:repo_id => @repo_id) do
        @model.send(:where, @opts).select(:id, @filename_field, :title).each do |result|
          rid      = result[:id]
          filename = filename_for(result[@filename_field])
          title    = result.title

          begin
            if @args.any?
              record = send(@method, rid, *@args)
            else
              record = send(@method, rid)
            end

            if @pdf
              record = generate_pdf_from_ead(record)
            elsif streaming_method?
              record = stream_to_record(record)
            end

            yield record, rid, filename, title if block_given?
          rescue Exception => ex
            $stderr.puts "#{rid.to_s} #{ex.message}"
            next
          end
        end
      end
    end

    def filename_for(field, delim = '_')
      "#{JSON.parse(field).join(delim).gsub(/(\s|\/)/, delim).squeeze(delim).chomp(delim)}#{@extension}"
    end

    def filename_field_for(model_sym)
      {
        accession: :identifier,
        digital_object: :digital_object_id,
        resource: :identifier,
      }[model_sym]
    end

    def model_class_from_sym(model_sym)
      {
        digital_object: DigitalObject,
        resource: Resource,
      }[model_sym]
    end

    def stream_to_record(record_stream)
      record = ""
      record_stream.each { |e| record << e }
      record
    end

    def streaming_method?
      [:generate_ead].include? @method
    end

    def write(record, directory, filename)
      output_path = File.join(directory, filename)
      $stdout.puts "Writing file to #{output_path}"
      if @pdf # record is a tmp file
        FileUtils.copy_file record, output_path
        FileUtils.rm record
      else # record is an xml string
        IO.write output_path, record
      end
      File.chmod(0644, output_path)
    end

  end
end
