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

What this piece of pseudocode states is that an object is an integer if it is either an integer (type), or if it is a string that can be converted to an integer.  With such rules, it becomes natural to also accept the value `"20"` as an integer.  It is also clearly defined so that a string that is not an integer, or `"20d"` and `"twenty"`, is not accepted as a string, which prevents any possible misinterpretations.  In this particular example, the domain accepted both Integer and String.

As for this particular repository, it is a proof of concept made through heavy usage of Ruby's metaprogramming and its natural to read syntax, so that it is easier to use, as if they were part of the language all along.

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

### 3) Declaration of variables

### 4) Combination of Domains

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

### 5) Implicit translations

### 6) Compile Time Type Checking

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

