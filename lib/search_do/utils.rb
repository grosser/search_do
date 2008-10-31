
module SearchDo
  class Utils
    MULTIBYTE_SPACE = [0x3000].pack("U")

    def self.cleanup_query(query)
      query.to_s.gsub(MULTIBYTE_SPACE,' ')
    end
  end
end

