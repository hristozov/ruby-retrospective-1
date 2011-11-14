class Array

  def to_hash
    result = {}
    each {|item| result[item[0]] = item[1]}
    result
  end

  def index_by
    map{ |n| [yield(n), n] }.to_hash
  end

  def occurences_count
    Hash.new(0).tap do |result|
      each{ |item| result[item] += 1}
    end
  end

  def subarray_count(subarray)
    each_cons(subarray.length).count(subarray)
  end
  
end
  
