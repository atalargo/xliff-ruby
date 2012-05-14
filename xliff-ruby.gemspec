$:.push File.dirname(__FILE__)+'/lib/'
require "xliff"

Gem::Specification.new do |s|
    s.name        = "xliff-ruby"
    s.version     = Xliff::VERSION
    s.authors     = ["Florent Ruard-Dumaine"]
    s.email       = ["florent.ruard-dumaine@iscool-e.com"]
    s.homepage    = "https://github.com/atalargo/xliff-ruby"
    s.summary     = %q{Xliff parser and generator for ruby}
    s.description = %q{This gem provide a parser and a generator lib for Xliff  (XML Localization Interchange File Format) version 1.2 of the XML schema}

    s.rubyforge_project = "string_to_sha1"

    s.files         = `git ls-files`.split("\n")
    s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
    s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
    s.require_paths = ["lib"]

    # specify any dependencies here; for example:
    # s.add_development_dependency "rspec"
    s.add_runtime_dependency "nokogiri"
end