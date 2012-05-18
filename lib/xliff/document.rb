require 'nokogiri'
require 'xliff/collection'
require 'xliff/notable'
require 'xliff/group'
require 'xliff/schema'

module Xliff
    class Document

        include Xliff::Collection

        XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2'

        # Xliff::Document constructor.
        # To open an existant xliff document, you can pass a filepathname, with or not a 2nd parameter to inform some options for create new unit etc.
        # To create a new one, you can give a hash option with
        # * :target_lang
        # * :source_lang
        # * :datatype
        # * :original
        # * :filepathname (to save the document later but not mandatory see method #save_to )
        # * :prefix_id to indicate a prefix setted on new unit created
        def initialize(filepathname = nil, options_create = nil)
            @namespace_xliff = nil
            if filepathname && filepathname.is_a?(String)
                @doc = Nokogiri::XML(File.open(filepathname))
                unless @doc.errors.empty?
                    @doc.errors.each do |err|
                        p err
                        p err.line
                        p err.column
                        p err.str1
                        p err.str2
                    end
                    throw Exception.new('XML parsing error in file "'+filepathname+'" : '+@doc.errors.join("\n"))
                end
                if @doc.namespaces.length > 0
                    get_prefix_for_xliff_ns
                end

                @filepathname = filepathname
            else
                if options_create.nil? && filepathname.is_a?(Hash)
                    options_create = filepathname
                    filepathname = nil
                end
                builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
                    xml.doc.create_internal_subset(
                        'xliff',
                        "-//XLIFF//DTD XLIFF//EN",
                        "http://www.oasis-open.org/committees/xliff/documents/xliff.dtd"
                    )
                    xml.xliff(:version => "1.2", :xmlns => Xliff::Document::XLIFF_NS, 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance','xsi:schemaLocation' => Xliff::Schema::V1_2_STRICT_LOCATION) {
                        xml.file(:datatype => 'plaintext', :original => '') {
                                xml.header {}
                                xml.body {}
                        }
                    }
                end

                @doc = Nokogiri::XML(builder.to_xml)

                get_prefix_for_xliff_ns

                options_create = {} if options_create.nil?
                options_create[:target_lang] = 'en' if options_create[:target_lang].nil?
                options_create[:source_lang] = 'en' if options_create[:source_lang].nil?
                self.source_lang = options_create[:source_lang]
                self.target_lang = options_create[:target_lang]
                @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['datatype'] = options_create[:datatype] if options_create[:datatype]
                @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['original'] = options_create[:original] if options_create[:original]
                @filepathname = options_create[:filepathname] if options_create[:filepathname]

            end
            @elem = @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file/#{@namespace_xliff}body").first
            @parent = @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first

            if options_create && !options_create[:prefix_id].nil?
                @prefix_id = options_create[:prefix_id]
            else
                @prefix_id = nil
            end

        end

        def get_prefix_for_xliff_ns
            return @namespace_xliff unless @namespace_xliff.nil?
            @namespace_xliff = 'xmlns'
            @doc.namespaces.each_with_index do |val, idx|
                if val[1] == Xliff::Document::XLIFF_NS
                    @namespace_xliff = val[0]
                    break
                end
            end
            @namespace_xliff += ':'
        end

        # Class method to open a given filepathname and execute a block on it if given, or return the xliff document instance if no block
        def self.open(filepathname, &block)
            xliff = Xliff::Document.new(filepathname)
            if block.nil?
                return xliff
            else
                yield xliff
            end
        end

        # Mehod to validate the current xliff document to on of available XML Schema of Xliff norm. transitional or strict.
        # Parameters are
        # * type :transitional by default but could be :strict
        # * xsd optional parameter. If given it muse be an instance of Nokigiri::XML::Schema for Xliff Schema. You could obtain an instance of the class for xliff schema by methos of #Xliff::Schema
        def validate(type = :transitional, xsd = nil)
            throw Exception.new('type in validation must be only :transitional or :strict') if type != :transitional && type != :strict
            if xsd.nil?
                xsd = Xliff::Schema.get_schema(type)
            elsif !xsd.is_a?(Nokogiri::XML::Schema)
                throw Exception.new('XSD parameter must be a Nokogiri::XML::Schema instance')
            end

            error_count = 0
            xsd.validate(@doc).each do |error|
                puts error.message
                error_count += 1
            end
            if error_count > 0
                p "#{error_count} error(s) found"
            else
                p "No Error. The Xliff is valid in #{type.to_s} mode"
            end
            return (error_count == 0)
        end

        # Class method to valide a xliff file file path given with XSD type given.
        # See #validate method
        def self.validate(document_filepath, type = :transitional)
            Xliff::Document.open(document_filepath) do |xliff_doc|
                xliff.validate(type)
            end
        end

        # Get all transunits of the document.
        #
        # Return a #Xliff::TransUnitCollection instance if not block used, or call block on each instance of transunits
        def transunits(&block)
            units = Xliff::TransUnitCollection.new(@doc.xpath("//#{@namespace_xliff}trans-unit"), self, @namespace_xliff)
            unless block.nil?
                units.each do |unit|
                    block.call unit
                end
            else
                units
            end
        end

        # Save current Xliff Document to file pathname. If file pathname given not finished by '.xlf' (the standard extension for xliff files), the method add it.
        def save_to(filepathname)
            unless @doc.errors.empty?
                throw Exception.new('Can\'t save mal formed doc ' + @doc.errors.join("\n"))
            end

            filepathname +='.xlf' if /\.xlf$/ !~ filepathname

            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['date'] = Time.new.getutc.strftime('%FT%TZ')
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['product-name'] = File.basename(filepathname,'.xlf')
            self.transunits.sort
            File.open(filepathname,'w') do |file|
                file << (@doc.to_xml({:encoding => 'UTF-8', :indent => 5}).gsub(
                                                '<trans-unit ',"\n        <trans-unit ").gsub(
                                                '<source',"\n          <source").gsub(
                                                '<target',"\n          <target").gsub(
                                                '<note',"\n          <note").gsub(
                                                '</trans-unit>',"\n        </trans-unit>\n").gsub(/\n?<\/body>/,"\n    </body>").gsub(/\n\s*\n/,"\n")
                        )
            end
            @filepathname = filepathname
        end

        # Save current Xliff document for the already setted file path (already call to #save_to method or if opened already exists Xliff )
        def save
            self.save_to(@filepathname)
        end

        #
        # * if replace_same_id == true, replace node in self by the one from xliff_from if unitid of both equal, if not append with new available id
        # * if replace_same_id == false, if same id, not replace, if id from xliff_from not exists, append in self, with new id available in self
        #
        def merge_by_id(xliff_from, replace_same_id = false)
            #ensure order from and self
            xliff_from.transunits.sort
            self.transunits.sort

            last = self.transunits.last
            xliff_from.transunits.each do |unit|
                existsalready = self.unit(unit.unitid)
                if existsalready
                    if replace_same_id
                        existsalready.source = unit.source
                        existsalready.approved = false if existsalready.target != unit.target
                        existsalready.target = unit.target
                    end
                else
                    lastid = last.unitid.succ
                    ntu = Xliff::TransUnit.dup(@doc, unit, @namespace_xliff)
                    ntu.unitid = lastid
                    last.node.add_next_sibling(ntu.node)
                    last = self.transunits.last
                end

            end
        end

        #
        # * if replace_same_source == true, replace target in self by the one from xliff_from if source of both equal, if not append with new available id
        # * if replace_same_source == false, if same id, not replace, if source from xliff_from not exists, append in self, with new id available in self
        #
        def merge_by_source(xliff_from, replace_same_source = false)
            #ensure order from and self
            xliff_from.transunits.sort
            self.transunits.sort

            last = self.transunits.last
            xliff_from.transunits.each do |unit|
                existsalready = self.unit_by_source(unit.source)
                if existsalready
                    if replace_same_source
                        existsalready.approved = false if existsalready.target != unit.target
                        existsalready.target = unit.target
                    end
                else
                    lastid = last.unitid.succ
                    ntu = Xliff::TransUnit.dup(@doc, unit, @namespace_xliff)
                    ntu.unitid = lastid
                    last.node.add_next_sibling(ntu.node)
                    last = self.transunits.last
                end

            end
        end


        # Get target language for file tag
        def target_lang
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['target-language']
        end

        # Set target language for file tag
        def target_lang=(lang)
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['target-language'] = lang
        end

        # Get source language for file tag
        def source_lang
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['source-language']
        end

        # Set source language for file tag
        def source_lang=(lang)
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['source-language'] = lang
        end

        #
        # Class method to create new instance for new Xliff doc with source language (sourcel) and target language (targetl) parameters.
        # It's an alias of Xliff.Document.new with less options available
        #
        def self.create(sourcel, targetl)
            Xliff::Document.new({:source_lang => sourcel, :target_lang => targetl})
        end

        # Get the body tag of first file tag
        def body
            @doc.xpath("//#{@namespace_xliff}body").first
        end

        # Reindex all the trans-units from 1 to X, with prefix given in new method option, or '' if not prefix given
        def reindex(prefix_id = nil)
            tuid = 1
            self.transunits.each do |unit|
                unit.unitid = "#{prefix_id}#{tuid}"
                tuid += 1
            end
        end

        # Get the schema version use by the current Xliff Document or transitional if not schema indicate in document
        def schema
            if @doc.root['xsi:schemaLocation'] == Xliff::Schema::V1_2_STRICT_LOCATION
                return :strict
            else
                return :transitional
            end
        end

        # Set the schema version for the current document.
        #
        # Type parameter could be :
        # * :transitional for http://docs.oasis-open.org/xliff/v1.2/cs02/xliff-core-1.2-strict.xsd
        # * :strict for http://docs.oasis-open.org/xliff/v1.2/cs02/xliff-core-1.2-transitional.xsd'
        def schema=(type)
            if type == :transitional && schema() != :transitional
                @doc.xpath("/#{@namespace_xliff}xliff").first['xsi:schemaLocation'] = Xliff::Schema::V1_2_TRANSITIONAL_LOCATION
            elsif type == :strict && schema() != :strict
                @doc.xpath("/#{@namespace_xliff}xliff").first['xsi:schemaLocation'] = Xliff::Schema::V1_2_STRICT_LOCATION
            elsif [:transitional, :strict].index(type).nil?
                throw Exception.new('Only strict or transitional type of XLIFF schema are accepted')
            end
            if @doc.xpath("/#{@namespace_xliff}xliff").first.namespaces()['xmlns:xsi'].nil?
                @doc.xpath("/#{@namespace_xliff}xliff").first['xmlns:xsi'] = 'http://www.w3.org/2001/XMLSchema-instance'
            end
        end
    end
end
