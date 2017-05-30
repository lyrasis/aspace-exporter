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

    def self.export(config)
      FileUtils.mkdir_p(config.output)
      $stdout.puts "Exporting records from ArchivesSpace: #{Time.now}"

      exporter = ArchivesSpace::Exporter.new(config)
      exporter.export do |record, id|
        if record
          output_filename = filename_for(config.name, config.opts[:repo_id], config.model, id)
          exporter.write(record, config.output, output_filename)
          $stdout.puts "Exported: #{id.to_s} as #{output_filename}"
        end
      end

      $stdout.puts "Export complete: #{Time.now}"
    end

    def self.filename_for(name, repo_id, model, id)
      "#{name.to_s}_repository_#{repo_id.to_s}_#{model.to_s}_#{id.to_s}"
    end

    def initialize(config)
      @model     = model_class_from_sym(config.model)
      @method    = config.method[:name]
      @args      = config.method[:args]
      @opts      = config.opts
      @repo_id   = config.opts[:repo_id]
      @pdf       = false
      @extension = ".xml"

      # pdf isn't in line with the rest =(
      if @method == :generate_pdf_from_ead
        @method    = :generate_ead
        @pdf       = true
        @extension = ".pdf"
      end
    end

    def export
      RequestContext.open(:repo_id => @repo_id) do
        @model.send(:where, @opts).select(:id).each do |result_id|
          rid = result_id[:id]

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

            yield record, rid if block_given?
          rescue Exception => ex
            $stderr.puts "#{rid.to_s} #{ex.message}"
            next
          end
        end
      end
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

    def write(record, directory, filename, add_extension = true)
      filename    = "#{filename}#{@extension}" if add_extension
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