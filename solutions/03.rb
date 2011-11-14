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

module Discount
  def self.build hash
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
      NilDiscount.new
    end
  end

  class GetOneFreeDiscount
    def initialize items_count
      @items_count = items_count
    end

    def discount price, quantity
      -(quantity / @items_count) * price
    end

    def to_s
      "(buy #{@items_count-1}, get 1 free)"
    end
  end

  class ThresholdDiscount
    def initialize max_items, discount_percent
      @max_items = max_items
      @discount_percent = discount_percent
    end

    def discount price, quantity
        if quantity >= @max_items
          -(quantity - @max_items) * price * (@discount_percent / 100.0)
        else
          0
        end
    end

    def to_s
      suffix = SuffixUtil.get_suffix(@max_items)
      "(#{@discount_percent}% off of every after the #{@max_items}#{suffix})"
    end
  end

  class PackageDiscount
    def initialize num_of_items, discount_percent
      @num_of_items = num_of_items
      @discount_percent = discount_percent
    end

    def discount price, quantity
      amount = quantity / @num_of_items
      -amount * @num_of_items * price * (@discount_percent / 100.0)
    end

    def to_s
      "(get #{@discount_percent}% off for every #{@num_of_items})"
    end
  end

  class NilDiscount
    def discount price, quantity
      0
    end

    def to_s
      ''
    end
  end
end

module Coupon
  def self.build name,hash
    type = hash.to_a.flatten.first
    value = hash.to_a.flatten.last.to_s.to_d
    case type
    when :percent
      PercentCoupon.new(name, value)
    when :amount
      AmountCoupon.new(name, value)
    else
      NilCoupon.new
    end
  end

  class PercentCoupon
    def initialize name, percent
      @percent = percent
      @name = name
    end

    def discount(total)
      (@percent / '100.0'.to_d) * total
    end

    def to_s
      "Coupon #{@name} - #{sprintf("%d", @percent)}% off"
    end
  end

  class AmountCoupon
    def initialize name, amount
      @amount = amount
      @name = name
    end

    def discount(total)
      [total, @amount].min
    end
    
    def to_s
      "Coupon #{@name} - #{sprintf("%.2f", @amount)} off"
    end
  end

  class NilCoupon
    def discount(total)
      0
    end
  end
end

class InvoicePrinter
  def initialize(cart)
    @cart = cart
  end

  def to_s
    @output = ""
    print_header
    print_items
    print_total
  end

  private
  def print_header
    print_separator
    print 'Name', 'qty', 'price'
    print_separator
  end

  def print_items
    @cart.items.each_key do |item|
      print item, @cart.items[item], amount(@cart.item_price(item) * @cart.items[item])
      if @cart.item_discount(item).nonzero?
        discount_price = @cart.item_discount(item)
        print "  #{@cart.discount_name(item)}", '', amount(discount_price)
      end
    end

    if @cart.coupon != nil 
      print @cart.coupon, '', amount(@cart.total - @cart.total(false))
    end
  end

  def print_total
    print_separator
    print 'TOTAL', '', amount(@cart.total)
    print_separator
  end

  def print_separator
    @output << "+#{'-'*48}+#{'-'*10}+\n"
  end

  def print(*args)
    @output << "| %-40s %5s | %8s |\n" % args 
  end

  def amount(decimal)
    #"%5.2f" % decimal
    sprintf("%.2f", decimal)
  end
end

class Cart
  attr_reader :items, :coupon

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
    @inventory.item_price name
  end

  def item_discount name
    discount = @inventory.item_discount name
    (@inventory.item_discount name).discount(item_price(name), @items[name])
  end

  def discount_name name
    @inventory.item_discount(name).to_s
  end

  def total usecoupons=true
    result = '0'.to_d
    @items.each_key do |key|
      result += (item_price key) * @items[key]
      result += item_discount key
    end
    if usecoupons 
      result -= @coupon.discount(result) if @coupon != nil
      result = result < 0 ? 0 : result
    end
    result
  end

  def invoice
    InvoicePrinter.new(self).to_s
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
    raise "Invalid price" if numeric_price < '0.01'.to_d\
                          or numeric_price > '999.99'.to_d
    raise "Item already registred" if @items[name] != nil
    @items[name] = price.to_d
    @discounts[name] = Discount.build discounts_hash
  end

  def register_coupon name, value
    @coupons[name] = Coupon.build(name, value)
  end

  def get_coupon name
    @coupons[name]
  end

  def item_price name
    @items[name]
  end

  def item_discount name
    @discounts[name]
  end

  def has_item? name
    @items[name] != nil
  end

  def new_cart
    Cart.new self
  end
end

