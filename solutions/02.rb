class SongParser
  def SongParser.parse string_to_parse, artist_tags
    name, artist, genres, tags_string = string_to_parse.split('.').map(&:strip)
    genre, subgenre = genres.split(',').map(&:strip)
    tags = []
    tags += tags_string.split(',').map(&:strip) if tags_string != nil
    tags += [subgenre.downcase] if subgenre != nil
    tags += [genre.downcase] + artist_tags[artist]
    Song.new name, artist, genre, subgenre, tags
  end
end

class Song
  attr_accessor :name, :artist, :genre, :subgenre, :tags
  
  def initialize name, artist, genre, subgenre, tags
    @name = name
    @artist = artist
    @genre = genre
    @subgenre = subgenre
    @tags = tags
  end
  
  def matches? criteria, value
    case criteria
    when :artist, :name, :genre, :subgenre 
      matches_field criteria, value
    when :tags
      matches_tags? value
    when :filter
      matches_filter? value
    end
  end

  def matches_field field, value
    send(field) == value
  end

  def matches_tags? tags
    Array(tags).all? {|tag| matches_tag? tag}
  end

  def matches_tag? tag
    if tag.end_with? '!'
      return (not matches_tag? tag[0...-1])
    end
    @tags.index(tag) != nil
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
    @songs = songs_as_string.split("\n")
        .map{|string_for_parsing|
          SongParser.parse string_for_parsing, artist_tags
        }
  end

  def find hash
    hash.inject(@songs) {|res, criteria|
      res &= @songs.select{|song| song.matches? criteria.first, criteria.last}
      res
    }
  end
end
