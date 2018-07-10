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
end

def testing_stuff
    Int :a

    a = 500
    puts 100 + a
end

testing_stuff











puts "passed!"