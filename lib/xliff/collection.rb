module Xliff
    module Collection
        include Enumerable

        def init_collector(namespace_xliff, doc, parent, elem)
            @namespace_xliff = namespace_xliff
            @elem = elem
            @doc = doc
            add_to(parent) unless parent.nil?

        end

        def add_to(parent)
            @parent = parent
            @parent.add_child(@elem)
        end

        def groups
            @elem.xpath('./group')
        end

        def add_group(ngroup)
            @elem.xpath('./group').last.add_next_sibling(ngroup.node)
        end

        def unit(idunit)
            elem = @elem.xpath("./#{@namespace_xliff}trans-unit[@id=$value]", nil, {:value => idunit.to_s}).first
            unless elem.nil?
                return Xliff::TransUnit.new(elem, @namespace_xliff)
            else
                nil
            end
        end

        def unit_by_source(src)
            elem = @elem.xpath("./#{@namespace_xliff}trans-unit/#{@namespace_xliff}source[. =$value]/..", nil, {:value => src}).first
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
            if @elem.xpath("./#{@namespace_xliff}trans-unit").last.nil?
                @elem.add_child(newunit.node)
            else
                @elem.xpath("./#{@namespace_xliff}trans-unit").last.add_next_sibling(newunit.node)
            end
            newunit
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
    end
end