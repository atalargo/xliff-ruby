require 'nokogiri'
require File.dirname(__FILE__)+'/schema'

module Xliff
    class Document

        XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2'

        def initialize(filepathname = nil, options_create = nil)
            @namespace_xliff = nil

            if filepathname && filepathname.is_a?(String)
                @doc = Nokogiri::XML(File.open(filepathname))
                unless @doc.errors.empty?
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
                    xml.xliff(:version => "1.2", :xmlns => Xliff::Document::XLIFF_NS) {
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

        def self.open(filepathname, &block)
            xliff = Xliff::Document.new(filepathname)
            if block.nil?
                return xliff
            else
                yield xliff
            end
        end

        def validate(type = :transitional, xsd = nil)
            throw Exception.new('type in validation must be only :transitional or :strict') if type != :transitional && type != :strict
            if xsd.nil?
                xsd = Xliff::Schema.get_schema(type)
            elsif !xsd.is_a?(Nokogiri::XML::Schema)
                throw Exception.new('XSD parameter must be a Nokogiri::XML::Schema instance')
            end

            #Nokogiri::XML::Schema(File.read((type == :transitional ? Xliff::Schema::V1_2_TRANSITIONAL : Xliff::Schema::V1_2_STRICT)))
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

        def self.validate(document_filepath, type = :transitional)
            Xliff::Document.open(document_filepath) do |xliff_doc|
                xliff.validate(type)
            end
        end

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

        def unit(idunit)
            elem = @doc.xpath("//#{@namespace_xliff}trans-unit[@id=$value]", nil, {:value => idunit.to_s}).first
            unless elem.nil?
                return Xliff::TransUnit.new(elem, @namespace_xliff)
            else
                nil
            end
        end

        def unit_by_source(src)
            elem = @doc.xpath("//#{@namespace_xliff}trans-unit/#{@namespace_xliff}source[. =$value]/..", nil, {:value => src}).first
            unless elem.nil?
                return Xliff::TransUnit.new(elem, @namespace_xliff)
            else
                nil
            end
        end

        def add_unit(unitid, src, tgt, approved, comment = nil)
            newunit = Xliff::TransUnit.create(@doc, @namespace_xliff)
            newunit.unitid = unitid
            newunit.source = src
            newunit.target = tgt
            newunit.approved = approved
            newunit.comment = comment
            if @doc.xpath("//#{@namespace_xliff}trans-unit").last.nil?
                @doc.xpath("//#{@namespace_xliff}body").last.add_child(newunit.node)
            else
                @doc.xpath("//#{@namespace_xliff}trans-unit").last.add_next_sibling(newunit.node)
            end
            newunit
        end

        def save_to(filepathname)
            unless @doc.errors.empty?
                throw Exception.new('Can\'t save mal formed doc ' + @doc.errors)
            end
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['date'] = Time.new.getutc.strftime('%FT%TZ')
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['product-name'] = File.basename(filepathname,'.xml')
            self.transunits.sort
            File.open(filepathname,'w') do |file|
                file << @doc.to_xml(:encoding => 'UTF-8', :indent => 2)
            end
            @filepathname = filepathname
        end

        def save
            self.save_to(@filepathname)
        end

        #
        # if replace_same_id == true, replace node in self by the one from xliff_from if unitid of both equal, if not append with new available id
        # if replace_same_id == false, if same id, not replace, if id from xliff_from not exists, append in self, with new id available in self
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
        # if replace_same_source == true, replace target in self by the one from xliff_from if source of both equal, if not append with new available id
        # if replace_same_source == false, if same id, not replace, if source from xliff_from not exists, append in self, with new id available in self
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

        def target_lang
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['target-language']
        end

        def target_lang=(lang)
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['target-language'] = lang
        end

        def source_lang
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['source-language']
        end

        def source_lang=(lang)
            @doc.xpath("/#{@namespace_xliff}xliff/#{@namespace_xliff}file").first['source-language'] = lang
        end

        def self.create(sourcel,targetl)
            Xliff::Document.new({:source_lang => sourcel, :target_lang => targetl})
        end

        def body
            @doc.xpath("//#{@namespace_xliff}body").first
        end

        def reindex(prefix_id = nil)
            tuid = 1
            self.transunits.each do |unit|
                unit.unitid = "#{prefix_id}#{tuid}"
                tuid += 1
            end
        end
    end
end
