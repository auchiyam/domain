require('./domain.rb')
extend Domain

puts "Last test: #{Time.now}"

def is_number?(x)
    true if Integer(x) rescue false
end

def is_float?(x)
    true if Float(x) rescue false
end

# a variable x is Int if:
#   x is an Integer
#   x is a String that can be interpreted as an integer
domain :Int do
    rule(Integer)
    rule(String) { |x| is_number?(x) }

    default(Integer)

    translation(String, :default) { |x| Integer(x) }
    translation(:default, String) { |x| x.to_s }
end

domain :Fl do
    rule(Float)
    rule(Integer)
    rule(String) { |x| is_float?(x) }

    default(Float)

    translation(String, :default) { |x| Float(x) }
    translation(Integer, :default) { |x| Float(x) }

    translation(:default, String) { |x| x.to_s }
    translation(:default, Integer) { |x| x.to_i }
end

a = Fl.new

a.value = Fl.new
a.value.value = Fl.new
a.value.value.value = 200.35

puts 500 + a











puts "passed!"