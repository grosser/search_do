#--
# Ruby interface of Hyper Estraier
#                                                       Copyright (C) 2004-2006 Mikio Hirabayashi
#                                                                            All rights reserved.
#  This file is part of Hyper Estraier.
#  Redistribution and use in source and binary forms, with or without modification, are
#  permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice, this list of
#      conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright notice, this list of
#      conditions and the following disclaimer in the documentation and/or other materials
#      provided with the distribution.
#    * Neither the name of Mikio Hirabayashi nor the names of its contributors may be used to
#      endorse or promote products derived from this software without specific prior written
#      permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
#  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
#  COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
#  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
#  OF THE POSSIBILITY OF SUCH DAMAGE.
#++
#:include:overview


require "uri"
require "socket"
require "stringio"



#
# Module for the namespace of Hyper Estraier
#
module EstraierPure
  #----------------------------------------------------------------
  #++ Abstraction of document.
  #----------------------------------------------------------------
  class Document
    #--------------------------------
    # public methods
    #--------------------------------
    public
    # Add an attribute.
    # `name' specifies the name of an attribute.
    # `value' specifies the value of the attribute.  If it is `nil', the attribute is removed.
    # The return value is always `nil'.
    def add_attr(name, value)
      Utility::check_types({ name=>String, value=>String }) if $DEBUG
      name = name.gsub(/[ \t\r\n\v\f]+/, " ")
      name = name.strip.squeeze(" ")
      value = value.gsub(/[ \t\r\n\v\f]+/, " ")
      value = value.strip.squeeze(" ")
      @attrs[name] = value
      nil
    end
    # Add a sentence of text.
    # `text' specifies a sentence of text.
    # The return value is always `nil'.
    def add_text(text)
      Utility::check_types({ text=>String }) if $DEBUG
      text = text.gsub(/[ \t\r\n\v\f]+/, " ")
      text = text.strip.squeeze(" ")
      @dtexts.push(text) if text.length
      nil
    end
    # Add a hidden sentence.
    # `text' specifies a hidden sentence.
    # The return value is always `nil'.
    def add_hidden_text(text)
      Utility::check_types({ text=>String }) if $DEBUG
      text = text.gsub(/[ \t\r\n\v\f]+/, " ")
      text = text.strip.squeeze(" ")
      @htexts.push(text) if text.length
      nil
    end
    # Attache keywords.
    # `kwords' specifies a map object of keywords.  Keys of the map should be keywords of the
    # document and values should be their scores in decimal string.
    # The return value is always `nil'.
    def set_keywords(kwords)
      Utility::check_types({ kwords=>Hash }) if $DEBUG
      @kwords = kwords
    end
    # Get the ID number.
    # The return value is the ID number of the document object.  If the object has never been
    # registered, -1 is returned.
    def id()
      @id
    end
    # Get a list of attribute names of a document object.
    # The return value is a list object of attribute names.
    def attr_names()
      @attrs.keys.sort
    end
    # Get the value of an attribute.
    # `name' specifies the name of an attribute.
    # The return value is the value of the attribute or `nil' if it does not exist.
    def attr(name)
      Utility::check_types({ name=>String }) if $DEBUG
      @attrs[name]
    end
    # Get a list of sentences of the text.
    # The return value is a list object of sentences of the text.
    def texts()
      @dtexts
    end
    # Concatenate sentences of the text of a document object.
    # The return value is concatenated sentences.
    def cat_texts()
      buf = StringIO::new
      for i in 0...@dtexts.length
        buf.write(" ") if i > 0
        buf.write(@dtexts[i])
      end
      buf.string
    end
    # Dump draft data of a document object.
    # The return value is draft data.
    def dump_draft()
      buf = StringIO::new
      keys = @attrs.keys.sort
      for i in 0...keys.length
        buf.printf("%s=%s\n", keys[i], @attrs[keys[i]])
      end
      if @kwords
        buf.printf("%%VECTOR");
        @kwords.each() do |key, value|
          buf.printf("\t%s\t%s", key, value);
        end
        buf.printf("\n");
      end
      buf.printf("\n")
      for i in 0...@dtexts.length
        buf.printf("%s\n", @dtexts[i])
      end
      for i in 0...@htexts.length
        buf.printf("\t%s\n", @htexts[i])
      end
      buf.string
    end
    # Get attached keywords.
    # The return value is a map object of keywords and their scores in decimal string.  If no
    # keyword is attached, `nil' is returned.
    def keywords()
      @kwords
    end
    #--------------------------------
    # private methods
    #--------------------------------
    private
    # Create a document object.
    # `draft' specifies a string of draft data.
    def initialize(draft = "")
      Utility::check_types({ draft=>String }) if $DEBUG
      @id = -1
      @attrs = {}
      @dtexts = []
      @htexts = []
      @kwords = nil
      if draft.length
        lines = draft.split(/\n/)
        num = 0
        while num < lines.length
          line = lines[num]
          num += 1
          break if line.length < 1
          if line =~ /^%/
            if line =~ /^%VECTOR\t/
              @kwords = {} unless @kwords
              fields = line.split(/\t/)
              i = 1
              while i < fields.length - 1
                @kwords[fields[i]] = fields[i+1]
                i += 2
              end
            end
            next
          end
          line = line.gsub(/[ \t\r\n\v\f]+/, " ")
          line = line.strip.squeeze(" ")
          if idx = line.index("=")
            key = line[0...idx]
            value = line[idx+1...line.length]
            @attrs[key] = value
          end
        end
        while num < lines.length
          line = lines[num]
          next unless line.length
          if line[0] == 0x9
            @htexts.push(line[1...line.length]) if line.length > 1
          else
            @dtexts.push(line)
          end
          num += 1
        end
      end
    end
  end
  #----------------------------------------------------------------
  #++ Abstraction of search condition.
  #----------------------------------------------------------------
  class Condition
    #--------------------------------
    # public constants
    #--------------------------------
    public
    # option: check N-gram keys skipping by three
    SURE = 1 << 0
    # option: check N-gram keys skipping by two
    USUAL = 1 << 1
    # option: without TF-IDF tuning
    FAST = 1 << 2
    # option: with the simplified phrase
    AGITO = 1 << 3
    # option: check every N-gram key
    NOIDF = 1 << 4
    # option: check N-gram keys skipping by one
    SIMPLE = 1 << 10
    #--------------------------------
    # public methods
    #--------------------------------
    public
    # Set the search phrase.
    # `phrase' specifies a search phrase.
    # The return value is always `nil'.
    def set_phrase(phrase)
      Utility::check_types({ phrase=>String }) if $DEBUG
      phrase = phrase.gsub(/[ \t\r\n\v\f]+/, " ")
      phrase = phrase.strip.squeeze(" ")
      @phrase = phrase
      nil
    end
    # Add an expression for an attribute.
    # `expr' specifies an expression for an attribute.
    # The return value is always `nil'.
    def add_attr(expr)
      Utility::check_types({ expr=>String }) if $DEBUG
      expr = expr.gsub(/[ \t\r\n\v\f]+/, " ")
      expr = expr.strip.squeeze(" ")
      @attrs.push(expr)
      nil
    end
    # Set the order of a condition object.
    # `expr' specifies an expression for the order.  By default, the order is by score descending.
    # The return value is always `nil'.
    def set_order(expr)
      Utility::check_types({ expr=>String }) if $DEBUG
      expr = expr.gsub(/[ \t\r\n\v\f]+/, " ")
      expr = expr.strip.squeeze(" ")
      @order = expr
      nil
    end
    # Set the maximum number of retrieval.
    # `max' specifies the maximum number of retrieval.  By default, the number of retrieval is
    # not limited.
    # The return value is always `nil'.
    def set_max(max)
      Utility::check_types({ max=>Integer }) if $DEBUG
      @max = max if(max >= 0)
      nil
    end
    # Set the number of skipped documents.
    # `skip' specifies the number of documents to be skipped in the search result.
    # The return value is always `nil'.
    def set_skip(skip)
      Utility::check_types({ skip=>Integer }) if $DEBUG
      @skip = skip if(skip >= 0)
      nil
    end
    # Set options of retrieval.
    # `options' specifies options: `Condition::SURE' specifies that it checks every N-gram
    # key, `Condition::USU', which is the default, specifies that it checks N-gram keys
    # with skipping one key, `Condition::FAST' skips two keys, `Condition::AGITO'
    # skips three keys, `Condition::NOIDF' specifies not to perform TF-IDF tuning,
    # `Condition::SIMPLE' specifies to use simplified phrase.  Each option can be specified at
    # the same time by bitwise or.  If keys are skipped, though search speed is improved, the
    # relevance ratio grows less.
    # The return value is always `nil'.
    def set_options(options)
      Utility::check_types({ options=>Integer }) if $DEBUG
      @options |= options
      nil
    end
    # Get the search phrase.
    # The return value is the search phrase.
    def phrase()
      @phrase
    end
    # Get expressions for attributes.
    # The return value is expressions for attributes.
    def attrs()
      @attrs
    end
    # Get the order expression.
    # The return value is the order expression.
    def order()
      @order
    end
    # Get the maximum number of retrieval.
    # The return value is the maximum number of retrieval.
    def max()
      @max
    end
    # Get the number of skipped documents.
    # The return value is the number of documents to be skipped in the search result.
    def skip()
      @skip
    end
    # Get options of retrieval.
    # The return value is options by bitwise or.
    def options()
      @options
    end
    #--------------------------------
    # private methods
    #--------------------------------
    private
    # Create a search condition object.
    def initialize()
      @phrase = nil
      @attrs = []
      @order = nil
      @max = -1
      @skip = 0
      @options = 0
    end
  end
  #----------------------------------------------------------------
  #++ Abstraction of document in result set.
  #----------------------------------------------------------------
  class ResultDocument
    #--------------------------------
    # public methods
    #--------------------------------
    public
    # Get the URI.
    # The return value is the URI of the result document object.
    def uri()
      @uri
    end
    # Get a list of attribute names.
    # The return value is a list object of attribute names.
    def attr_names()
      @attrs.keys.sort
    end
    # Get the value of an attribute.
    # The return value is the value of the attribute or `nil' if it does not exist.
    def attr(name)
      Utility::check_types({ name=>String }) if $DEBUG
      @attrs[name]
    end
    # Get the snippet of a result document object.
    # The return value is a string of the snippet of the result document object.  There are tab
    # separated values.  Each line is a string to be shown.  Though most lines have only one
    # field, some lines have two fields.  If the second field exists, the first field is to be
    # shown with highlighted, and the second field means its normalized form.
    def snippet()
      @snippet
    end
    # Get keywords.
    # The return value is a string of serialized keywords of the result document object.  There
    # are tab separated values.  Keywords and their scores come alternately.
    def keywords()
      @keywords
    end
    #--------------------------------
    # private methods
    #--------------------------------
    private
    # Create a result document object.
    def initialize(uri, attrs, snippet, keywords)
      Utility::check_types({ uri=>String, attrs=>Hash,
                             snippet=>String, keywords=>String }) if $DEBUG
      @uri = uri
      @attrs = attrs
      @snippet = snippet
      @keywords = keywords
    end
  end
  #----------------------------------------------------------------
  #++ Abstraction of result set from node.
  #----------------------------------------------------------------
  class NodeResult
    #--------------------------------
    # public methods
    #--------------------------------
    public
    # Get the number of documents.
    # The return value is the number of documents.
    def doc_num()
      @docs.length
    end
    # Get the value of hint information.
    # The return value is a result document object or `nil' if the index is out of bounds.
    def get_doc(index)
      Utility::check_types({ index=>Integer }) if $DEBUG
      return nil if index < 0 || index >= @docs.length
      @docs[index]
    end
    # Get the value of hint information.
    # `key' specifies the key of a hint.  "VERSION", "NODE", "HIT", "HINT#n", "DOCNUM", "WORDNUM",
    # "TIME", "LINK#n", and "VIEW" are provided for keys.
    # The return value is the hint or `nil' if the key does not exist.
    def hint(key)
      Utility::check_types({ key=>String }) if $DEBUG
      @hints[key]
    end
    #--------------------------------
    # private methods
    #--------------------------------
    private
    # Create a node result object.
    def initialize(docs, hints)
      Utility::check_types({ docs=>Array, hints=>Hash }) if $DEBUG
      @docs = docs
      @hints = hints
    end
  end
  #----------------------------------------------------------------
  #++ Abstraction of connection to P2P node.
  #----------------------------------------------------------------
  class Node
    #--------------------------------
    # public methods
    #--------------------------------
    public
    # Set the URL of a node server.
    # `url' specifies the URL of a node.
    # The return value is always `nil'.
    def set_url(url)
      Utility::check_types({ url=>String }) if $DEBUG
      @url = url
      nil
    end
    # Set the proxy information.
    # `host' specifies the host name of a proxy server.
    # `port' specifies the port number of the proxy server.
    # The return value is always `nil'.
    def set_proxy(host, port)
      Utility::check_types({ host=>String, port=>Integer }) if $DEBUG
      @pxhost = host
      @pxport = port
      nil
    end
    # Set timeout of a connection.
    # `sec' specifies timeout of the connection in seconds.
    # The return value is always `nil'.
    def set_timeout(sec)
      Utility::check_types({ sec=>Integer }) if $DEBUG
      @timeout = sec
      nil
    end
    # Set the authentication information.
    # `name' specifies the name of authentication.
    # `passwd' specifies the password of the authentication.
    # The return value is always `nil'.
    def set_auth(name, password)
      Utility::check_types({ name=>String, password=>String }) if $DEBUG
      @auth = name + ":" + password
      nil
    end
    # Get the status code of the last request.
    # The return value is the status code of the last request.  -1 means failure of connection.
    def status()
      @status
    end
    # Add a document.
    # `doc' specifies a document object.  The document object should have the URI attribute.
    # The return value is true if success, else it is false.
    def put_doc(doc)
      Utility::check_types({ doc=>Document }) if $DEBUG
      @status = -1
      return false if !@url
      turl = @url + "/put_doc"
      reqheads = [ "Content-Type: text/x-estraier-draft" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = doc.dump_draft
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, nil)
      @status = rv
      rv == 200
    end
    # Remove a document.
    # `id' specifies the ID number of a registered document.
    # The return value is true if success, else it is false.
    def out_doc(id)
      Utility::check_types({ id=>Integer }) if $DEBUG
      @status = -1
      return false if !@url
      turl = @url + "/out_doc"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "id=" + id.to_s
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, nil)
      @status = rv
      rv == 200
    end
    #  Remove a document specified by URI.
    # `uri' specifies the URI of a registered document.
    # The return value is true if success, else it is false.
    def out_doc_by_uri(uri)
      Utility::check_types({ uri=>String }) if $DEBUG
      @status = -1
      return false if !@url
      turl = @url + "/out_doc"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "uri=" + URI::encode(uri)
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, nil)
      @status = rv
      rv == 200
    end
    # Edit attributes of a document.
    # `doc' specifies a document object.
    # The return value is true if success, else it is false.
    def edit_doc(doc)
      Utility::check_types({ doc=>Document }) if $DEBUG
      @status = -1
      return false if !@url
      turl = @url + "/edit_doc"
      reqheads = [ "Content-Type: text/x-estraier-draft" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = doc.dump_draft
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, nil)
      @status = rv
      rv == 200
    end
    # Retrieve a document.
    # `id' specifies the ID number of a registered document.
    # The return value is a document object.  On error, `nil' is returned.
    def get_doc(id)
      Utility::check_types({ id=>Integer }) if $DEBUG
      @status = -1
      return nil if !@url
      turl = @url + "/get_doc"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "id=" + id.to_s
      resbody = StringIO::new
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, resbody)
      @status = rv
      return nil if rv != 200
      Document::new(resbody.string)
    end
    # Retrieve a document.
    # `uri' specifies the URI of a registered document.
    # The return value is a document object.  On error, `nil' is returned.
    def get_doc_by_uri(uri)
      Utility::check_types({ uri=>String }) if $DEBUG
      @status = -1
      return nil if !@url
      turl = @url + "/get_doc"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "uri=" + URI::encode(uri)
      resbody = StringIO::new
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, resbody)
      @status = rv
      return nil if rv != 200
      Document::new(resbody.string)
    end
    # Retrieve the value of an attribute of a document.
    # `id' specifies the ID number of a registered document.
    # `name' specifies the name of an attribute.
    # The return value is the value of the attribute or `nil' if it does not exist.
    def get_doc_attr(id, name)
      Utility::check_types({ id=>Integer, name=>String }) if $DEBUG
      @status = -1
      return nil if !@url
      turl = @url + "/get_doc_attr"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "id=" + id.to_s + "&attr=" + URI::encode(name)
      resbody = StringIO::new
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, resbody)
      @status = rv
      return nil if rv != 200
      resbody.string.chomp
    end
    # Retrieve the value of an attribute of a document specified by URI.
    # `uri' specifies the URI of a registered document.
    # `name' specifies the name of an attribute.
    # The return value is the value of the attribute or `nil' if it does not exist.
    def get_doc_attr_by_uri(uri, name)
      Utility::check_types({ uri=>String, name=>String }) if $DEBUG
      @status = -1
      return nil if !@url
      turl = @url + "/get_doc_attr"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "uri=" + URI::encode(uri) + "&attr=" + URI::encode(name)
      resbody = StringIO::new
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, resbody)
      @status = rv
      return nil if rv != 200
      resbody.string.chomp
    end
    # Extract keywords of a document.
    # `id' specifies the ID number of a registered document.
    # The return value is a hash object of keywords and their scores in decimal string or `nil'
    # on error.
    def etch_doc(id)
      Utility::check_types({ id=>Integer }) if $DEBUG
      @status = -1
      return nil if !@url
      turl = @url + "/etch_doc"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "id=" + id.to_s
      resbody = StringIO::new
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, resbody)
      @status = rv
      return nil if rv != 200
      kwords = {}
      lines = resbody.string.split(/\n/)
      for i in 0...lines.length
        pair = lines[i].split(/\t/)
        next if pair.length < 2
        kwords[pair[0]] = pair[1]
      end
      kwords
    end
    # Extract keywords of a document specified by URI.
    # `uri' specifies the URI of a registered document.
    # The return value is a hash object of keywords and their scores in decimal string or `nil'
    # on error.
    def etch_doc_by_uri(uri)
      Utility::check_types({ uri=>String }) if $DEBUG
      @status = -1
      return nil if !@url
      turl = @url + "/etch_doc"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "uri=" + URI::encode(uri);
      resbody = StringIO::new
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, resbody)
      @status = rv
      return nil if rv != 200
      kwords = {}
      lines = resbody.string.split(/\n/)
      for i in 0...lines.length
        pair = lines[i].split(/\t/)
        next if pair.length < 2
        kwords[pair[0]] = pair[1]
      end
      kwords
    end
    # Get the ID of a document specified by URI.
    # `uri' specifies the URI of a registered document.
    # The return value is the ID of the document.  On error, -1 is returned.
    def uri_to_id(uri)
      Utility::check_types({ uri=>String }) if $DEBUG
      @status = -1
      return -1 if !@url
      turl = @url + "/uri_to_id"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "uri=" + URI::encode(uri)
      resbody = StringIO::new
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, resbody)
      @status = rv
      return nil if rv != 200
      resbody.string.chomp
    end
    # Get the name.
    # The return value is the name.  On error, `nil' is returned.
    def name()
      set_info if !@name
      @name
    end
    # Get the label.
    # The return value is the label.  On error, `nil' is returned.
    def label()
      set_info if !@label
      @label
    end
    # Get the number of documents.
    # The return value is the number of documents.  On error, -1 is returned.
    def doc_num()
      set_info if @dnum < 0
      @dnum
    end
    # Get the number of unique words.
    # The return value is the number of unique words.  On error, -1 is returned.
    def word_num()
      set_info if @wnum < 0
      @wnum
    end
    # Get the size of the datbase.
    # The return value is the size of the datbase.  On error, -1.0 is returned.
    def size()
      set_info if @size < 0.0
      @size
    end
    # Search documents corresponding a condition.
    # `cond' specifies a condition object.
    # `depth' specifies the depth of meta search.
    # The return value is a node result object.  On error, `nil' is returned.
    def search(cond, depth)
      Utility::check_types({ cond=>Condition, depth=>Integer }) if $DEBUG
      @status = -1
      return nil if !@url
      turl = @url + "/search"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = Utility::cond_to_query(cond, depth, @wwidth, @hwidth, @awidth)
      resbody = StringIO::new
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, resbody)
      @status = rv
      return nil if rv != 200
      lines = resbody.string.split(/\n/)
      return nil if lines.length < 1
      docs = []
      hints = {}
      nres = NodeResult::new(docs, hints)
      border = lines[0]
      isend = false
      lnum = 1
      while lnum < lines.length
        line = lines[lnum]
        lnum += 1
        if line.length >= border.length && line.index(border) == 0
          isend = true if line[border.length...line.length] == ":END"
          break
        end
        lidx = line.index("\t")
        if lidx
          key = line[0...lidx]
          value = line[(lidx+1)...line.length]
          hints[key] = value
        end
      end
      snum = lnum
      while !isend && lnum < lines.length
        line = lines[lnum]
        lnum += 1
        if line.length >= border.length && line.index(border) == 0
          if lnum > snum
            rdattrs = {}
            sb = StringIO::new
            rdvector = ""
            rlnum = snum
            while rlnum < lnum - 1
              rdline = lines[rlnum].strip
              rlnum += 1
              break if rdline.length < 1
              if rdline =~ /^%/
                lidx = rdline.index("\t")
                rdvector = rdline[(lidx+1)...rdline.length] if rdline =~ /%VECTOR/ && lidx
              else
                lidx = rdline.index("=")
                if lidx
                  key = rdline[0...lidx]
                  value = rdline[(lidx+1)...rdline.length]
                  rdattrs[key] = value
                end
              end
            end
            while rlnum < lnum - 1
              rdline = lines[rlnum]
              rlnum += 1
              sb.printf("%s\n", rdline)
            end
            rduri = rdattrs["@uri"]
            rdsnippet = sb.string
            if rduri
              rdoc = ResultDocument::new(rduri, rdattrs, rdsnippet, rdvector)
              docs.push(rdoc)
            end
          end
          snum = lnum
          isend = true if line[border.length...line.length] == ":END"
        end
      end
      return nil if !isend
      return nres
    end
    # Set width of snippet in the result.
    # `wwidth' specifies whole width of a snippet.  By default, it is 480.  If it is 0, no
    # snippet is sent. If it is negative, whole body text is sent instead of snippet.
    # `hwidth' specifies width of strings picked up from the beginning of the text.  By default,
    # it is 96.  If it is negative 0, the current setting is not changed.
    # `awidth' specifies width of strings picked up around each highlighted word. By default,
    # it is 96.  If it is negative, the current setting is not changed.
    def set_snippet_width(wwidth, hwidth, awidth)
      @wwidth = wwidth;
      @hwidth = hwidth if hwidth >= 0
      @awidth = awidth if awidth >= 0
    end
    # Manage a user account of a node.
    # `name' specifies the name of a user.
    # `mode' specifies the operation mode.  0 means to delete the account.  1 means to set the
    # account as an administrator.  2 means to set the account as a guest.
    # The return value is true if success, else it is false.
    def set_user(name, mode)
      Utility::check_types({ name=>String, mode=>Integer }) if $DEBUG
      @status = -1
      return false if !@url
      turl = @url + "/_set_user"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "name=" + URI::encode(name) + "&mode=" + mode.to_s
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, nil)
      @status = rv
      rv == 200
    end
    # Manage a link of a node.
    # `url' specifies the URL of the target node of a link.
    # `label' specifies the label of the link.
    # `credit' specifies the credit of the link.  If it is negative, the link is removed.
    # The return value is true if success, else it is false.
    def set_link(url, label, credit)
      Utility::check_types({ url=>String, label=>String, credit=>Integer }) if $DEBUG
      @status = -1
      return false if !@url
      turl = @url + "/_set_link"
      reqheads = [ "Content-Type: application/x-www-form-urlencoded" ]
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      reqbody = "url=" + URI::encode(url) + "&label=" + label
      reqbody += "&credit=" + credit.to_s if credit >= 0
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, reqbody, nil, nil)
      @status = rv
      rv == 200
    end
    #--------------------------------
    # private methods
    #--------------------------------
    private
    # Create a node connection object.
    def initialize()
      @url = nil
      @pxhost = nil
      @pxport = -1
      @timeout = -1
      @auth = nil
      @name = nil
      @label = nil
      @dnum = -1
      @wnum = -1
      @size = -1.0
      @wwidth = 480;
      @hwidth = 96;
      @awidth = 96;
      @status = -1
    end
    # Set information of the node.
    def set_info()
      @status = -1
      return if !@url
      turl = @url + "/inform"
      reqheads = []
      reqheads.push("Authorization: Basic " + Utility::base_encode(@auth)) if @auth
      resbody = StringIO::new
      rv = Utility::shuttle_url(turl, @pxhost, @pxport, @timeout, reqheads, nil, nil, resbody)
      @status = rv
      return if rv != 200
      lines = resbody.string.chomp.split(/\n/)
      return if lines.length < 1
      elems = lines[0].chomp.split(/\t/)
      return if elems.length != 5
      @name = elems[0]
      @label = elems[1]
      @dnum = elems[2].to_i
      @wnum = elems[3].to_i
      @size = elems[4].to_f
    end
  end
  #:stopdoc:
  #
  # Module for utility
  #
  module Utility
    public
    # Check types of arguments
    # `types' specifies a hash object whose keys are arguments and values are class objects.
    # If there is a invalid object, an exception is thrown.
    def check_types(types)
      i = 0
      types.each_key do |key|
        i += 1
        unless key.kind_of?(types[key]) || key == nil
          raise ArgumentError::new("Argument#" + i.to_s +
                                     " should be a kind of " + types[key].to_s)
        end
      end
    end
    module_function :check_types
    # Perform an interaction of a URL.
    # `url' specifies a URL.
    # `pxhost' specifies the host name of a proxy.  If it is `nil', it is not used.
    # `pxport' specifies the port number of the proxy.
    # `outsec' specifies timeout in seconds.  If it is negative, it is not used.
    # `reqheads' specifies a list object of extension headers.  If it is `nil', it is not used.
    # `reqbody' specifies the pointer of the entitiy body of request.  If it is `nil', "GET"
    # method is used.
    # `resheads' specifies a list object into which headers of response is stored.  If it is
    # `nil' it is not used.
    # `resbody' specifies stream object into which the entity body of response is stored.  If it
    # is `nil', it is not used.
    # The return value is the status code of the response or -1 on error.
    def shuttle_url(url, pxhost, pxport, outsec, reqheads, reqbody, resheads, resbody)
      begin
        status = -1
        th = Thread::start do
          url = URI::parse(url)
          url.normalize
          Thread::current.exit if url.scheme != "http" || !url.host || url.port < 1
          if pxhost
            host = pxhost
            port = pxport
            query = "http://" + url.host + ":" + url.port.to_s + url.path
          else
            host = url.host
            port = url.port
            query = url.path
          end
          query += "?" + url.query if url.query && !reqbody
          begin
            sock = TCPSocket.open(host, port)
            if reqbody
              sock.printf("POST " + query + " HTTP/1.0\r\n")
            else
              sock.printf("GET " + query + " HTTP/1.0\r\n")
            end
            sock.printf("Host: %s:%d\r\n", url.host, url.port)
            sock.printf("Connection: close\r\n")
            sock.printf("User-Agent: HyperEstraierForRuby/1.0.0\r\n")
            if reqheads
              reqheads.each do |line|
                sock.printf("%s\r\n", line)
              end
            end
            sock.printf("Content-Length: %d\r\n", reqbody.length) if reqbody
            sock.printf("\r\n")
            sock.write(reqbody) if reqbody
            line = sock.gets.chomp
            elems = line.split(/  */)
            Thread::current.exit if elems.length < 3 || !(elems[0] =~ /^HTTP/)
            status = elems[1].to_i
            resheads.push(line) if resheads
            begin
              line = sock.gets.chomp
              resheads.push(line) if resheads
            end while line.length > 0
            while buf = sock.read(8192)
              resbody.write(buf) if resbody
            end
          ensure
            sock.close if sock
          end
        end
        if outsec >= 0
          unless th.join(outsec)
            th.exit
            th.join
            return -1
          end
        else
          th.join
        end
        return status
      rescue
        return -1
      end
    end
    module_function :shuttle_url
    # Serialize a condition object into a query string.
    # `cond' specifies a condition object.
    # `depth' specifies depth of meta search.
    # `wwidth' specifies whole width of a snippet.
    # `hwidth' specifies width of strings picked up from the beginning of the text.
    # `awidth' specifies width of strings picked up around each highlighted word.
    # The return value is the serialized string.
    def cond_to_query(cond, depth, wwidth, hwidth, awidth)
      buf = StringIO::new
      if cond.phrase
        buf.write("&") if buf.length > 0
        buf.write("phrase=")
        buf.write(URI::encode(cond.phrase))
      end
      for i in 0...cond.attrs.length
        buf.write("&") if buf.length > 0
        buf.write("attr" + (i + 1).to_s + "=")
        buf.write(URI::encode(cond.attrs[i]))
      end
      if cond.order
        buf.write("&") if buf.length > 0
        buf.write("order=")
        buf.write(URI::encode(cond.order))
      end
      if cond.max > 0
        buf.write("&") if buf.length > 0
        buf.write("max=" + cond.max.to_s)
      else
        buf.write("&") if buf.length > 0
        buf.write("max=" + (1 << 30).to_s)
      end
      buf.write("&options=" + cond.options.to_s) if cond.options > 0
      buf.write("&depth=" + depth.to_s) if depth > 0
      buf.write("&wwidth=" + wwidth.to_s)
      buf.write("&hwidth=" + hwidth.to_s)
      buf.write("&awidth=" + awidth.to_s)
      buf.write("&skip=" + cond.skip.to_s)
      buf.string
    end
    module_function :cond_to_query
    # Encode a byte sequence with Base64 encoding.
    # `data' specifyes a string object.
    # The return value is the encoded string.
    def base_encode(data)
      [data].pack("m").gsub(/[ \n]/, "")
    end
    module_function :base_encode
  end
end



# END OF FILE
