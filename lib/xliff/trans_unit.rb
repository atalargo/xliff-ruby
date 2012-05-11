module Xliff
    class TransUnitCollection
        include Enumerable

        def initialize(transunitscoll, xliff, namespace_xliff = nil)
            @transunitscoll = transunitscoll
            @xliff = xliff
            @namespace_xliff = namespace_xliff
        end

        def each(&block)
            @transunitscoll.each do |unit|
                block.call Xliff::TransUnit.new(unit, @namespace_xliff)
            end
        end

        def sort
            newt = Nokogiri::XML::NodeSet.new(@transunitscoll.document, @transunitscoll.to_ary.sort_by{|unit| Xliff::TransUnit.new(unit, @namespace_xliff)})
            @transunitscoll.first.parent.children = newt
            @transunitscoll = newt
        end

        def last
            Xliff::TransUnit.new(@transunitscoll.last, @namespace_xliff)
        end

        def <<(transunit)
            if @transunitscoll.empty?
                body = @xliff.body
                body.add_child(transunit.node.dup)
                @transuitscoll = @xliff.transunits
            else
                @transunitscoll.last.add_next_sibling(transunit.node.dup)
            end
            self
        end

    end

    class TransUnit
        include Comparable

        def initialize(nokigiriunit = nil, namespace = nil)
            @unit = nokigiriunit
            @namespace = namespace
        end

        def self.create(doc, namespace_xliff = nil)
            unit = Xliff::TransUnit.new(Nokogiri::XML::Node.new('trans-unit', doc), @namespace_xliff)
            newsrc = Nokogiri::XML::Node.new "source", doc
            unit.node.add_child(newsrc)
            newtgt = Nokogiri::XML::Node.new "target", doc
            unit.node.add_child(newtgt)
            unit
        end

        def self.dup(doc, old, namespace_xliff = nil)
            unit = self.create(doc, namespace_xliff)
            unit.unitid = old.unitid
            unit.source = old.source
            unit.target = old.target
            unit
        end

        def unitid
            @unit['id']
        end

        def source
            @unit.xpath(".//#{@namespace}source").first.content
        end

        def target
            @unit.xpath(".//#{@namespace}target").first.content
        end

        def comment
        end

        def target=(tgt)
            @unit.xpath(".//#{@namespace}target").first.content = tgt
        end

        def source=(src)
            @unit.xpath(".//#{@namespace}source").first.content = src
        end

        def unitid=(uid)
            @unit['id'] = uid.to_s
        end

        def comment=(com)
        end

        def <=>(b)
            self.unitid.to_i <=> b.unitid.to_i
        end

        def node
            @unit
        end

        def approved?
            return !(@unit['approved'].nil? || @unit['approved'] == 'no')
        end

        def approved=(approve)
            @unit['approved'] = (approve ? 'yes' : 'no')
        end

    end
end