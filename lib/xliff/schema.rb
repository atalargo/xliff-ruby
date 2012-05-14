module Xliff
    module Schema
        V1_2_STRICT = File.dirname(__FILE__)+'/../../xsd/xliff-core-1.2-strict.xsd' #'http://docs.oasis-open.org/xliff/v1.2/cs02/xliff-core-1.2-strict.xsd'
        V1_2_TRANSITIONAL = File.dirname(__FILE__)+'/../../xsd/xliff-core-1.2-transitional.xsd' #'http://docs.oasis-open.org/xliff/v1.2/cs02/xliff-core-1.2-transitional.xsd'

        V1_2_STRICT_LOCATION = 'urn:oasis:names:tc:xliff:document:1.2 xliff-core-1.2-strict.xsd'
        V1_2_TRANSITIONAL_LOCATION = 'urn:oasis:names:tc:xliff:document:1.2 xliff-core-1.2-transitional.xsd'

        def self.get_strict_schema
            self.get_schema(:strict)
        end
        def self.get_transitional_schema
            self.get_schema(:transitional)
        end
        def self.get_schema(type)
            Nokogiri::XML::Schema(File.read((type == :transitional ? self::V1_2_TRANSITIONAL : self::V1_2_STRICT)))
        end
    end
end
