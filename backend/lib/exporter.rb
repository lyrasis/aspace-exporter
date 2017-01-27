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
      records = []
      RequestContext.open(:repo_id => @repo_id) do
        @model.send(:where, @opts).select(:id).each do |result_id|
          rid = result_id[:id]
          if @args.any?
            record = send(@method, rid, *@args)
          else
            record = send(@method, rid)
          end
          records << record
          yield record, rid if block_given?
        end
      end
      records
    end

    def model_class_from_sym(model_sym)
      {
        digital_object: DigitalObject,
        resource: Resource,
      }[model_sym]
    end

  end

end