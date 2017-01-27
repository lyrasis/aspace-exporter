module ArchivesSpace

  class Exporter

    include ExportHelpers
    include URIResolver

    def initialize(model, method, opts = {})
      @model   = model_class_from_sym(model)
      @method  = method[:name]
      @args    = method[:args]
      @opts    = opts
      @repo_id = opts[:repo_id]
      @pdf     = false

      # pdf isn't in line with the rest =(
      if @method == :generate_pdf_from_ead
        @method = :generate_ead
        @pdf    = true
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

  end
end