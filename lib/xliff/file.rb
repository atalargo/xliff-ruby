module Xliff
    class File
        include Xliff::Collection

        def initialize(elem, doc, namespace, parent = nil)
            @elem = elem
            init_collector(namespace, doc, parent, @elem)
        end

        def self.create(doc,namespace, attributes, parent = nil)
            self.check_attributes(attributes)
            elem = Nokogiri::XML::Node.new('file', doc)
            if parent.xpath("./#{namespace}file").length > 0
                parent.xpath("./#{namespace}file").last.add_next_sibling(elem)
            else
                parent.add_child(elem).
            end
            t = new Xliff::File.new(elem, doc, namespace, parent)
            t.set_attributes(attributes)
        end

        def check_attributes(attributes)
            throw new Exception('attributes parameter must be a Hash') if !attributes.is_a?(Hash)
            missing_mandatory = ['original', 'source-language', 'datatype'].reject{|key| attributes[key] }
            throw new Exception("attributes '#{missing_mandatory.join("', '")}' are mandatory for file tag")
        end

        def set_attributes(attributes)
            self.check_attributes(attributes)
            attributes.keys.each do |key|
                @elem[key] = attributes[key]
            end
        end
    end
end
