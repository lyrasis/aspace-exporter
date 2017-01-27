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
    end

    def export
      RequestContext.open(:repo_id => @repo_id) do
        @model.send(:where, @opts).select(:id).each do |result_id|
          rid = result_id[:id]
          if @args.any?
            record = send(@method, rid, *@args)
          else
            record = send(@method, rid)
          end

          record = stream_to_record(record) if streaming_method?
          yield record, rid if block_given?
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