class Array

  def to_hash
    self.inject({}) do |result, item|
      result[item[0]] = item[1]
      result
    end
  end

  def index_by
    self.inject({}) do
      |result, item| result[yield item] = item
      result
    end
  end

  def occurences_count
    self.inject(Hash.new(0)) do |result, item|
      result[item] += 1
      result
    end
  end

  def subarray_count(subarray)
    each_cons(subarray.length).count(subarray)
  end
  
end
  
