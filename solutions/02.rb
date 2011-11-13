class Song
  attr_accessor :name, :artist, :genre, :subgenre, :tags
  
  def parse string_to_parse, artist_tags
    @name = string_to_parse[0]
    @artist = string_to_parse[1]
    genrestring = string_to_parse[2].split(',').map(&:strip)
    @genre = genrestring[0]
    @tags = [@genre.downcase]
    if genrestring[1] != nil
      @subgenre = genrestring[1]
      @tags << @subgenre.downcase
    end
    if string_to_parse[3] != nil 
      @tags.concat(string_to_parse[3].split(',').map(&:strip))
    end
    @tags.concat(artist_tags[@artist])
  end

  def matches? criteria, value
    case criteria
    when :artist
      matches_artist? value
    when :name
      matches_name? value
    when :tags
      matches_tag? value
    when :filter
      matches_filter? value
    end
  end

  def matches_tag? tag
    if tag.kind_of? String
      if tag[-1] == "!"
        @tags.index(tag[0...-1]) == nil
      else
        @tags.index(tag) != nil
      end
    elsif tag.kind_of? Array
      result = true
      tag.each do |tag_element|
        result &= matches_tag? tag_element
      end
      result
    end
  end

  def matches_name? name
    @name == name
  end

  def matches_artist? artist
    @artist == artist
  end

  def matches_filter? filterfunc
    filterfunc.call(self)
  end
end

class Collection
  def initialize songs_as_string, artist_tags
    artist_tags.default = []
    @songs = songs_as_string.split("\n")\
      .map{|line| line.split('.').map &:strip}\
        .map{|string_for_parsing|
          song = Song.new
          song.parse(string_for_parsing,artist_tags)
          song
        }
  end

  def find hash
    hash.inject(@songs) {|res, criteria|
      res &= @songs.select{|song| song.matches? criteria.first, criteria.last}
      res
    }
  end
end
