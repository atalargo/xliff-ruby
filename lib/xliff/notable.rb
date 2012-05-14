module Xliff
    module Notable

        def note
            @elem.xpath("./#{@namespace}note").first
        end

        def note=(com)
            if self.note
                self.note.content = com
            else
                newnote = Nokogiri::XML::Node.new "note", @elem.document
                newnote.content = com
                @elem.add_child(newnote)
            end
        end

    end
end
