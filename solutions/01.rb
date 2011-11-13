class Array

  def to_hash
    self.inject({}) {|result, item| result[item[0]] = item[1]; result}
  end

  def index_by
    self.inject({}) {|result, item| result[yield item] = item; result}
  end

  def occurences_count
    self.inject(Hash.new(0)) {|result, item| result[item] += 1; result }
  end

  def subarray_count(subarray)
   result = 0
   (0...self.size).each do |i|
     result +=1 if self[i...i+subarray.size] == subarray
   end
   result
  end
  
end
  
