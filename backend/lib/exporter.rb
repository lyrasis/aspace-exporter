module ArchivesSpace

  class Exporter

    include ExportHelpers
    include URIResolver

    Config = Struct.new(:name, :model, :method, :opts, :output) do
      # name: default
      # model: resource
      # method: { name: generate_ead, args: [] }
      # opts: { repo_id: 2, id: nil }
      # output: "/tmp/exports"
    end

    attr_reader :extension, :pdf

    def self.delete_file(output, filename)
      Dir[File.join(output, filename)].each { |f| FileUtils.rm(f) }
    end

    def self.export(config)
      FileUtils.mkdir_p(config.output)
      manifest = get_manifest_path(config.output, config[:name])
      write_manifest_headers(manifest) unless File.file? manifest

      $stdout.puts "Exporting records from ArchivesSpace: #{Time.now}"

      exporter = ArchivesSpace::Exporter.new(config)
      exporter.export do |record, id, filename|
        if record
          exporter.write(record, config.output, filename)
          $stdout.puts "Exported: #{id.to_s} as #{filename}"

          # ADD / UPDATE MANIFEST (location,filename,uri,updated_at,deleted)
          data = [
            location_to("files/exports", filename), # TODO: path arg
            filename,
            uri_for(config.opts[:repo_id], config.model, id),
            Time.now,
            false,
          ]
          $stdout.puts "Manifest: #{data.join(',')}"
          update_manifest(manifest, data)
        end
      end

      $stdout.puts "Export complete: #{Time.now}"
    end

    def self.find_in_manifest?(manifest, data)
      IO.foreach(manifest).grep(/#{Regexp.escape(data)}/).take(1).any?
    end

    def self.get_manifest_path(output, name)
      File.join(output, "manifest_#{name}.csv")
    end

    def self.location_to(path, filename)
      "#{AppConfig[:frontend_proxy_url]}/#{path}/#{filename}"
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
    end

    def self.write_manifest_headers(manifest)
      CSV.open(manifest, 'a') do |csv|
        csv << ["location", "filename", "uri", "updated_at", "deleted"]
      end
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
        @model.send(:where, @opts).select(:id, @filename_field).each do |result_id|
          rid      = result_id[:id]
          filename = filename_for(result_id[@filename_field])

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

            yield record, rid, filename if block_given?
          rescue Exception => ex
            $stderr.puts "#{rid.to_s} #{ex.message}"
            next
          end
        end
      end
    end

    def filename_for(field, delim = '_')
      "#{JSON.parse(field).join(delim).gsub(/\s/, delim).squeeze(delim).chomp(delim)}#{@extension}"
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
      if @pdf
        FileUtils.cp record, output_path
      else
        IO.write output_path, record
      end
    end

  end
end
