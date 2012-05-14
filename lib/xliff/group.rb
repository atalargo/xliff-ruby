module Xliff
    class Group
        include Xliff::Collection
        include Xliff::Notable

        def initialize(doc, namespace, parent = nil)
            elem = Nokogiri::XML::Node.new('group', doc)
            init_collector(namespace, doc, parent, elem)
        end


    end
end
