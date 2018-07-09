# Domain

## What is Domain?

>In mathematics, and more specifically in naive set theory, the _domain of definition_ (or simply the _domain_) of a function is the set of "input" or argument values for which the function is defined  
>~*Domain of a function Wikipedia page*

Domain is a set of rules an object must follow in order for the object to be accepted.  It is inspired by the mathematical concept of domain of a function defined above.  In the programming context, domain acts similarly to a generalized form of types, because it is a form of identifying an object.  A simple example would be the object `"20"`.  In types, `"20"` is strictly string, and nothing more.  However, suppose a domain for integer was defined as follows:

```
# Ruby-like pseudocode
def is_integer(x)
  return Integer(x) rescue false
end

domain Integer
  rule(Integer): true
  rule(String): |x| is_integer(x)
end
```

What this piece of pseudocode states is that an object is an integer if it is either an integer (type), or if it is a string that can be converted to an integer.  With such rules, it becomes natural to also accept the value `"20"` as an integer.  It is also clearly defined so that a string that is not an integer, or `"20d"` and `"twenty"`, is not accepted as a string, which prevents any possible misinterpretations.

This repository is a proof of concept made through heavy usage of Ruby's metaprogramming and its natural to read syntax, so that it is easier to use, as if they were part of the language all along.

## Features

### 1) Declaration of the domain

#### Theory

Declaration of the domain is straightforward: domain can be declared and defined like any other classes, like so:

```
# Ruby-like pseudocode
domain Integer
  rule(Integer): true
  rule(String): |x| is_integer(x)
  rule: |x| (x is Integer) or (x is String)
end
```

The `rule` function takes the domain (or class) and the rule it applies to.  The rule should be an anonymous function that, from 1 argument, return a boolean value on whether that value is part of the domain or not.  In this example, Integer would always return true, so any integer values would be accepted.  String, on the other hand, must go through the anonymous function that checks if the String x can be converted to Integer.  Finally, the third rule without any argument indicates that every type must pass this rule.

#### Implementation

In this code, the domain can be declared as follows:

```
domain :Integer do
  rule(Integer)
  rule(String) { |x| is_integer(x) }
end
```

`domain` function accepts a symbol and block, symbol being the name of the domain, preferably in constant format due to limitation in Ruby's metaprogramming.  Within the block, the user must specify some rules for the domain.  `rule` accepts a domain and block to imitate the specification as much as possible.

### 2) Defining the domain and codomain of the function

#### Theory

Domain, like the mathematical counterpart, should primarily be used to label what the input/output of the function are.  The syntax should be similar to the types, or in other words, something like this:

```
# Ruby-like pseudocode
def foo(Integer x) -> Integer
  x + 50
end
```

This would indicate that the function`foo` would only accept Integer as the argument, and it would only return Integer as the output.

#### Implementation

In this code, the feature is implemented like so:

```
domain 'Integer -> Integer'
def foo(x)
  x + 50
end
```

The domain before the arrow would indicate the arguments or input, and the domain after the arrow would indicate the returned value.

It is also possible to label all 6 different types of argument used in Ruby like so:

```
domain 'Integer, $Integer, *Integer, key1: Integer, key2: $Integer, **Integer -> nil'
def foo(req, opt = 5, *arg, key1:, key2: 5, **kwarg)
end
```

special keywords `%any%` and `nil` also exists to allow users to have more control over their code.  `%any%` will accept any object regardless of the domain, and `nil`, only usable in the return value side, indicate that there are no return values

### 3) Declaration of variables

#### Theory

Declaration of variables is also a feature similar to static type system, in which variables are declared as being part of the domain.  Once it is declared as one domain, it cannot accept any object that are not part of the domain.  An example:

```
#Ruby-like pseudocode
def foo(Integer x)

end

def bar() -> String
  "300"
end

Integer x
String y

x = 500         # no error
x = "500"       # no error
# x = "String"  # error
# x = bar()     # error

# y = 500       # error
y = "500"       # no error
y = bar()       # no error

foo(x)          # no error
# foo(y)        # error
```

x and y are declared to be part of domains `Integer` and `String` respectively, so any object that are part of the domain are accepted without any error.  Additionally, notice how the `x = bar()` and `foo(y)` cause an error.  This is because String is not a subset of Integer, so even if the actual value can be interpreted as an Integer, it is not accepted.

#### Implementation

This feature is implemented in this code as follows:

```
x = Integer.new

x.value = 50        # no error
x.value = "50"      # no error
x.value = "String"  # error
```

Unfortunately, no declaration of variables is possible in Ruby as the Binding class's `local_variable_set()` method does not allow creation of a new variable.  Additionally, because `x = <value>` would replace its domain, it is also not a very secure way to implement this code, as you can accidentally override the status of the domain for variable x easily.

An alternative, slow method is to use a tracepoint that would slow the program down by up to three times.  It can, however, check the value upon every assignment.  Perhaps it can be implemented simply for illustration purpose.

### 4) Combination of Domains

#### Theory

Because domain is based on the mathematical term, it can also respond well to set operations such as union, intersection, difference, and complement.  This allows domains to create complex rules in an intuitive and easy way.  For example, suppose the program should only accept an integer in string format, perhaps to store it as a user ID or credit card number where it does not make sense to accept any other string, but representing it in integer cause unwanted overflow.  In other languages, this would mean that you must write a lengthy if statements to determine that it is the proper object.  In domain, however, it is possible to do:

```
# Ruby-like pseudocode

domain Integer
  rule(Integer): true
  rule(String): |x| is_integer(x)
end

UserID = Integer ∩ String

def accept(id: UserID)
  # code
end
```

The UserID is defined as the intersection of integer and string, meaning it must both be a String and Integer.  So if a regular Integer was passed, although it pass the restriction imposed by Integer domain, it does not satisfy the String restriction.

#### Implementation

The combination of domains can be achieved through this syntax:

```
X = Integer & String    # Intersection
Y = Integer + String    # Union
Z = Integer - String    # Difference
```

The syntax is chosen based on array, because domains are supposed to be a set of objects that are part of certain group.  The operations intersection, union, and difference all act similarly to Ruby's intersection, union, and difference operations for array.

### 5) Implicit conversions

#### Theory

Because domains are not types, the objects must be converted back and forth based on how the objects are being used; for example:

```
# Ruby-like pseudocode
IntegerString = Integer ∩ String     # Because intersection means the value resides in both, it should respond to both methods

def bar(x: Integer) -> Integer
  x + 20
end

def foo(x: IntegerString)
  puts x.length                       # converted to strings
  puts x + 10                         # converted to Integer
  bar(x)                              # converted to Integer
end

IntegerString x

x = "290"                             # both integer and string

foo(x)                                # -> 3
                                      # -> 300
```
 
variable `x` with domain IntegerString can respond to both String and Integer's method calls because internally, the values accepted by Integer and String must be able to respond to both.

#### Implementation

There are various limits to the Ruby's implicit conversions that makes some of the implicit conversions impossible.  However, here are several ways this code achieve this functionality:

* Ability to specify translation rules in the domain declaration:
  ```
  domain :Integer do
    rule(Integer)
    rule(String) { |x| is_integer(x) }
  
    default(Integer)
  
    translate(String, :default) { |x| x.to_i }
    translate(:default, String) { |x| x.to_s }
  end
  ```

  `translate` method takes domain A and domain B as argument and a block that successfully change the value from A -> B.  The argument also takes the symbol `:default` as an argument, which will be discussed later

  `default` method takes a domain as an argument, which creates a "default" value for the object.  This default value is used to find another path that was not directly specified.  For example, suppose that a domain has translation rules for `Integer -> String` and `String -> Float`, and you want to translate Integer -> Float.  Because there are no direct Integer -> Float translation rules, one can set String as default value, which would make the domain also try Integer -> String -> Float translation, which exists.

  Perhaps in the future, there can be an algorithm that can find a path without relying on a default value.

* Automatically creating implicit conversion methods such as `to_ary` and `to_int` whenever there are rules that translate objects to them.

  The weakness to this approach is that not all classes has a method that are implicitly called, such as float.

* Generating a coerce method whenever mathematical translations are needed, so it can be interpreted properly.

  This allows variables to be interpreted properly in cases like `x + complex_class`

* Running method_missing so that if a method has been called for one of the output translation, the value is translated and then the method is called.

  This allows the object to respond to any method that it can be converted to.

### 6) Compile Time Type Checking

### 7) Equality between two different domains

## Strengths

There are various different strengths domain offers over both dynamically typed languages and statically typed languages.  Here are couple of examples:

### 1) Duck Typing

Duck typing is a form of typing that was named from the famous phrase "If it looks like a duck, swims like a duck, and quacks like a duck, then it probably is a duck.".  It roughly states that as long as the object behaves a certain way, the program should not care if it actually is the object they are looking for, which is a duck in the quote's case.

#### Statically typed languages

In statically typed languages, it is almost impossible to implement duck typing in an acceptable way.  You can make every objects that should act like a duck inherit or implement a parent class or interface of some kind, but it is not feasible to keep inheriting the same class/interface over and over as the code base grows, therefore, duck typing principles in statically typed language is not feasible.

#### Dynamically typed languages

It is pretty trivial to write a duck typed program in dynamically typed languages, like below:

```
# Ruby
def lengthy(x)
  x.length
end

class Lengthy
  def length
    10
  end
end

puts lengthy("Hello World!")  # 12
puts lengthy([1,2,3,4,5])     # 5
puts lengthy(Lengthy.new)     # 10
```

Despite the fact that x is a String or Array, both would be acceptable as they define their own length method.  Additionally, a brand new class that has the `length` method would also be accepted without any trouble, as dynamically typed languages does not care about the type of the object until the program requires the information.  However, what if someone sent an object that does not respond to the `length` method?  As the program grow, the lack of compile time security of the dynamically typed language will slowly make the debugging of the program harder, as the program will only throw an error at runtime rather than compile time.

#### Domain

With the use of domains, the duck typing is both relatively more safe and easy to implement:

```
# Ruby-like pseudocode

domain Lengthy
  rule: |x| x.respond_to?(:length)
end

def lengthy(x: Lengthy)
  x.length
end

class LengthyClass
  def length
    10
  end
end

puts lengthy("Hello World!")    # 12
puts lengthy([1,2,3,4,5])       # 5
puts lengthy(LengthyClass.new)  # 10
puts lengthy(50)                # Error inducing
```

The domain goes a step further the dynamically typed language and implement the type safety like the statically typed languages.  In an ideal case, the compiler would read the script and realize that Integer:50 does not fall under the Lengthy domain, and thus raise an error warning the programmer of such.

### 2) Clear formalization of rules

