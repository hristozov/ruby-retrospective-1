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
      -(@percent / '100.0'.to_d) * total
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
      -[total, @amount].min
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

class Product
  attr_reader :name, :price, :discount

  def initialize name, price, discount
    raise "Invalid name passed" if name.length > 40
    raise "Invalid price" unless price > 0 and price < 1000
    @name = name
    @price = price
    @discount = discount
  end
end

class LineItem
  attr_reader :product
  attr_accessor :quantity

  def initialize(product, quantity)
    @product = product
    @quantity = 0

    increase quantity
  end

  def increase(quantity)
    raise 'Invalid number of items' if quantity <= 0
    raise 'Invalid number of items' if quantity + @quantity > 99
    @quantity += quantity
  end

  def product_name
    @product.name
  end

  def discounted_price
    price + discount
  end

  def price
    product.price * quantity
  end

  def discount
    product.discount.discount(product.price, quantity)
  end

  def discount_name
    product.discount.to_s
  end

  def discounted?
    not discount.zero?
  end
end

class InvoicePrinter
  def initialize(cart)
    @cart = cart
  end

  def to_s
    @output = ""
    print_separator
    print 'Name', 'qty', 'price'
    print_separator
    print_items
    print_total
  end

  private
  def print_items
    @cart.items.each do |item|
      print item.product_name, item.quantity, amount(item.price)
      print_discount item
    end

    if not @cart.coupon.is_a?(Coupon::NilCoupon)
      print @cart.coupon, '', amount(@cart.total - @cart.total(false))
    end
  end

  def print_discount item
    print "  #{item.discount_name}", '', amount(item.discount) if item.discounted?
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
    sprintf("%.2f", decimal)
  end
end

class Cart
  attr_reader :items, :coupon

  def initialize inv
    @inventory = inv
    @items = []
    @coupon = Coupon::NilCoupon.new()
  end

  def add name, quantity=1
    product = @inventory[name]
    item = @items.find { |item| item.product == product } 
    if item
      item.quantity += quantity
    else
      @items << LineItem.new(product, quantity)
    end
  end

  def total usecoupons=true
    items_price = @items.map(&:discounted_price).inject(&:+)
    discount = @coupon.discount items_price
    usecoupons ? items_price + discount : items_price
  end

  def invoice
    InvoicePrinter.new(self).to_s
  end

  def use name
    raise "Coupon already set!" if not @coupon.is_a?(Coupon::NilCoupon)
    @coupon = @inventory.get_coupon name
  end
end

class Inventory
  def initialize
    @items = {}
    @coupons = {}
  end

  def register name, price, discounts_hash = nil
    price = price.to_d
    @items[name] = Product.new(name, price, Discount.build(discounts_hash))
  end

  def [](name)
    @items[name] or raise 'No such product.'
  end

  def register_coupon name, value
    @coupons[name] = Coupon.build(name, value)
  end

  def get_coupon name
    @coupons[name] or Coupon.NilCoupon.new
  end

  def new_cart
    Cart.new self
  end
end

