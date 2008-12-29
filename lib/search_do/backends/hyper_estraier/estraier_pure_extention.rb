require 'search_do/backends/hyper_estraier'

module SearchDo::Backends
  module HyperEstraier::EstraierPureExtention
    def self.included(base)
      [Node,Condition,NodeResult,ResultDocument].each do |klas|
        basic_class_name = klas.to_s.split('::').last
        base.const_get(basic_class_name).send(:include, klas)
      end
    end

    module Node
      def list
        return false unless @url
        turl = @url + "/list"
        reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
        reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
        reqbody = ""
        resbody = StringIO::new
        rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, resbody)
        @status = rv
        return nil if rv != 200
        lines = resbody.string.split(/\n/)
        lines.collect { |l| val = l.split(/\t/) and { :id => val[0], :uri => val[1], :digest => val[2] } }
      end
    end

    module Condition
      def to_s
        "phrase: %s, attrs: %s, max: %s, options: %s, order: %s, skip: %s" % [ phrase, attrs * ', ', max, options, order, skip ]
      end
    end

    module NodeResult
      include Enumerable
      def each(&block)
        (0...doc_num).each{|i| yield get_doc(i) }
      end

      def docs; map{|e| e } ; end

      def first_doc; get_doc(0); end
    end

    module ResultDocument
      #wacky snippet string parsed into a nice array of lines
      #where the found word (here: a search for bob) is marked to be highlighted
      #[["hallo my name is ",false],["bob",true],[" butcher",false]]
      #output does not contain HTML
      def snippet_a
        snip = @snippet.sub(/^\.+/,"\n")#first ... can be understood as \n
        snip.split("\n").reject{|x|x==''}.map do |part|
          part.include?("\t") ? [part.split("\t")[0],true] : [part,false]
        end
      end
    end
  end
end

::EstraierPure.send(:include, SearchDo::Backends::HyperEstraier::EstraierPureExtention)

