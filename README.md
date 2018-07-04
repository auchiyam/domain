# domain

## What is domain?

Domain is a form of type created to help make the dynamically typed language more secure, but not as strict as statically typed languages.  Thus domain typing lies somewhere between statically typed languages and dynamically typed languages.

As for this particular code, it is a proof of concept made through heavy usage of Ruby's metaprogramming and its natural to read syntax, so that it is more easy to use, as if they were part of the language all along.  I realize that there are probably better ways to implement the functionalities through low level means such as implementing the functionality directly to the Ruby language, however, because it is merely a proof of concept, I have opted for something easier to implement in.

## Domain vs Types

Domains are set of rules an object must follow in order for the object to be accepted.  Domains are more general form of types, since domains can accept any object as long as they follow the rules, while types must be exact.  A simple example would be the object `"20"`.  In types, `"20"` is strictly string, and nothing more.  However, suppose a domain for integer was defined as follows:

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

## Strengths

There are various different strengths domain offers over both dynamically typed languages and statically typed languages.  Here are couple of examples:

### 1) Duck Typing

Duck typing is a form of typing that was named from the famous phrase "If it walks like a duck, and quacks like a duck, then it is a duck".  It roughly states that as long as the object behaves a certain way, the program should not care if it actually is the object they are looking for, which is a duck in the quote's case.

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
  rule: |x| respond_to?(:length)
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

### 2) Combination of Domains
### 3) Clear formalization of rules
