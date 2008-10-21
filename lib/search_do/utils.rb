
module SearchDo
  module Utils
    MULTIBYTE_SPACE = [0x3000].pack("U")
    PRESERVED_QUERY_WORDS_RE = /(AND|OR|ANDNOT)/

    def tokenize_query(query)
      tokens = query.to_s.scan(/'([^']*)'|"([^"]*)"|([^\s#{MULTIBYTE_SPACE}]*)/).flatten.reject(&:blank?)
      tokens.map do |token|
        token.gsub!(PRESERVED_QUERY_WORDS_RE, $1.downcase) if token =~ PRESERVED_QUERY_WORDS_RE
        token.gsub!(/\A['"]|['"]\z/, '') # strip quatos
        token
      end.join(" AND ")
    end

    module_function :tokenize_query
  end
end

