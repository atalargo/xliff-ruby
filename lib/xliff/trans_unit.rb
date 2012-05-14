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
        include Xliff::Notable

        def initialize(nokigiriunit = nil, namespace = nil)
            @elem = nokigiriunit
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
            @elem['id']
        end

        def source
            @elem.xpath(".//#{@namespace}source").first.content
        end

        def target
            @elem.xpath(".//#{@namespace}target").first.content
        end

#         def note
#             @unit.xpath(".//#{@namespace}note").first
#         end
#
#         def note=(com)
#             if self.note
#                 self.note.content = com
#             else
#                 newnote = Nokogiri::XML::Node.new "note", @unit.document
#                 newnote.content = com
#                 @unit.add_child(newnote)
#             end
#         end

        def target=(tgt)
            @elem.xpath(".//#{@namespace}target").first.content = tgt
        end

        def source=(src)
            @elem.xpath(".//#{@namespace}source").first.content = src
        end

        def unitid=(uid)
            @elem['id'] = uid.to_s
        end


        def <=>(b)
            self.unitid.to_i <=> b.unitid.to_i
        end

        def node
            @elem
        end

        def approved?
            return !(@elem['approved'].nil? || @elem['approved'] == 'no')
        end

        def approved=(approve)
            @elem['approved'] = (approve ? 'yes' : 'no')
        end

    end
end