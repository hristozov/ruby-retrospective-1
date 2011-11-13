require 'bigdecimal'
require 'bigdecimal/util'

class SuffixUtil
  def self.get_suffix number
    case number%10
    when 1
      "st"
    when 2
      "nd"
    when 3
      "rd"
    else
      "th"
    end
  end
end

class BaseDiscount
  def get_lambda value, quantity
    raise "This should be overriden"
  end

  def to_s
    raise "This should be overriden"
  end
end

class GetOneFreeDiscount < BaseDiscount
  def initialize items_count
    @items_count = items_count
  end

  def get_lambda item_price
    lambda do |quantity|
      -(quantity / @items_count) * (item_price)
    end
  end

  def to_s
    "(buy #{@items_count-1}, get 1 free)"
  end
end

class ThresholdDiscount < BaseDiscount
  def initialize max_items, discount_percent
    @max_items = max_items
    @discount_percent = discount_percent
  end

  def get_lambda item_price
    lambda do |quantity|
      if quantity >= @max_items
        -(quantity - @max_items) * item_price * (@discount_percent / 100.0)
      else
        0
      end
    end
  end

  def to_s
    suffix = SuffixUtil.get_suffix(@max_items)
    "(#{@discount_percent}% off of every after the #{@max_items}#{suffix})"
  end
end

class PackageDiscount < BaseDiscount
  def initialize num_of_items, discount_percent
    @num_of_items = num_of_items
    @discount_percent = discount_percent
  end

  def get_lambda item_price
    lambda do |quantity|
      amount = quantity / @num_of_items
      -amount * @num_of_items * item_price * (@discount_percent / 100.0)
    end
  end

  def to_s
    "(get #{@discount_percent}% off for every #{@num_of_items})"
  end
end

class DiscountsFactory
  def self.get_discount hash
    type = hash.to_a.flatten.first
    value = hash.to_a.flatten.last
    case type
    when :get_one_free
      GetOneFreeDiscount.new(value)
    when :package
      PackageDiscount.new(value.to_a.flatten.first, value.to_a.flatten.last)
    when :threshold
      ThresholdDiscount.new(value.to_a.flatten.first, value.to_a.flatten.last)
    else
      nil
    end
  end
end

class BaseCoupon
  def get_lambda
    raise "This should be overriden!"
  end

  def to_s
    raise "This should be overriden!"
  end
end

class PercentCoupon < BaseCoupon
  def initialize name, percent
    @percent = percent
    @name = name
  end

  def get_lambda
    lambda do |total|
      -total * (@percent / 100.0)
    end
  end

  def to_s
    "Coupon #{@name} - #{sprintf("%d", @percent)}% off"
  end
end

class AmountCoupon < BaseCoupon
  def initialize name, amount
    @amount = amount
    @name = name
  end

  def get_lambda
    lambda do |total|
      -@amount
    end
  end

  def to_s
    "Coupon #{@name} - #{sprintf("%.2f", @amount)} off"
  end
end

class CouponFactory 
  def self.get_coupon name, hash
    type = hash.to_a.flatten.first
    value = hash.to_a.flatten.last
    case type
    when :percent
      PercentCoupon.new(name, value)
    when :amount
      AmountCoupon.new(name, value)
    else
      nil
    end
  end
end

class Cart
  def initialize inv
    @inventory = inv
    @items = Hash.new(0)
  end

  def add name, quantity=1
    raise "Invalid item name" if not @inventory.has_item? name
    @items[name] += quantity
    raise "Invalid quantity" if quantity <= 0 or quantity > 99
  end

  def item_price name
    (@inventory.item_price name) * @items[name]
  end

  def item_discount name
    discount = @inventory.get_item_discount name
    if discount != nil
      (@inventory.get_item_discount name).call(@items[name])
    else
      0
    end
  end

  def total usecoupons=true
    result = '0'.to_d
    @items.each_key do |key|
      result += item_price key
      result += item_discount key
    end
    if usecoupons 
      result += @coupon.get_lambda.call(result) if @coupon != nil
      result = result < 0 ? 0 : result
    end
    result
  end

  def invoice
    ret = "+#{'-'*48}+#{'-'*10}+\n"
    ret << "| #{'Name'.ljust 23}#{'qty'.rjust 23} |#{'price'.rjust 9} |\n"
    ret << "+#{'-'*48}+#{'-'*10}+\n"
    ret << invoice_for_each_item
    ret << invoice_for_coupon if @coupon != nil
    ret << "+#{'-'*48}+#{'-'*10}+\n"
    ret << "| #{'TOTAL'.ljust 46} |#{sprintf('%.2f',total).rjust 9} |\n"
    ret << "+#{'-'*48}+#{'-'*10}+\n"
  end

  def invoice_for_each_item
    res = ""
    @items.each_key do |key|
      quantity = sprintf("%d", @items[key])
      price = sprintf("%.2f", @inventory.item_price(key) * @items[key])
      res << "| #{key.ljust 23}#{quantity.rjust 23} |#{price.rjust 9} |\n"
      res << invoice_for_discount(key)
    end
    res
  end

  def invoice_for_discount name
    res = ""
    discount_desc = @inventory.get_item_discount_string name
    if discount_desc != nil
      discount = @inventory.get_item_discount(name).call(@items[name])
      discount_string = sprintf('%.2f', discount)
      res << "|   #{discount_desc.ljust 44} |#{discount_string.rjust 9} |\n"
    end
    res
  end

  def invoice_for_coupon
    if @coupon != nil
      coupon_discount = sprintf("%.2f", total - total(false))
      "| #{@coupon.to_s.ljust 46} |#{coupon_discount.rjust 9} |\n"
    end
  end

  def use name
    raise "Coupon already set!" if @coupon != nil
    @coupon = @inventory.get_coupon name
  end
end

class Inventory
  def initialize
    @items = {}
    @discounts = {}
    @coupons = {}
  end

  def register name, price, discounts_hash = nil
    numeric_price = price.to_d
    raise "Invalid name passed" if name.length > 40
    raise "Invalid pricei" if numeric_price < '0.01'.to_d or numeric_price > '999.99'.to_d
    raise "Item already registred" if @items[name] != nil
    @items[name] = price.to_d
    @discounts[name] = DiscountsFactory.get_discount discounts_hash 
  end

  def register_coupon name, value
    @coupons[name] = CouponFactory.get_coupon(name, value)
  end

  def get_coupon name
    @coupons[name]
  end

  def item_price name
    @items[name]
  end

  def get_item_discount name
    @discounts[name] != nil ? @discounts[name].get_lambda(item_price name) : nil
  end

  def get_item_discount_string name
    @discounts[name] != nil ? @discounts[name].to_s : nil
  end
  
  def has_item? name
    @items[name] != nil
  end

  def new_cart
    Cart.new self
  end
end

