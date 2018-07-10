module DomainClass
    attr_accessor :rules
    attr_accessor :translators
    attr_accessor :compound_domain
    attr_accessor :default

    def print_rules
        puts "compound~~~~~~~~~~~~~~~~~"
        if compound_domain != self
            pp(compound_domain.rules)
        end
        puts "~~~~~~~~~~~~~~~~~compound"

        puts "self~~~~~~~~~~~~~~~~~~~~"
        pp(rules)
        puts "~~~~~~~~~~~~~~~~~~~~self"
    end

    def print_translators
        puts "compound~~~~~~~~~~~~~~~~~"
        if compound_domain != self
            pp compound_domain.translators
        end
        puts "~~~~~~~~~~~~~~~~~compound"

        puts "self~~~~~~~~~~~~~~~~~~~~"
        pp translators
        puts "~~~~~~~~~~~~~~~~~~~~self"
    end

    # determine if the value is a valid value for the domain
    def value?(value)
        compound = true

        if has_compound_domain
            compound = compound_domain.value? value
        end

        indiv = check_rules(rules, value)

        compound && indiv
    end

    def check_rules(rules, value)
        # initialization.  
        valid = true # stores whether the value is valid for the domain or not
        checked = rules.empty? # to see whether that type is checked or not.  If it was not checked, it means that there were no rules that match the domain

        if value.class == self
            return true
        end

        # iterate through every rules in the domain
        rules.each do |type, rule_list|

            # If the type is nil, then apply the rule to every type
            if type == nil
                # if it didn't apply, the value is invalid
                rule_list.each do |rule|
                    if not rule.call value
                        valid = false
                    end 
                end
                # the value has successfully been checked
                checked = true
                next
            end

            # If the type was specified, see if the type matches.  If so, apply rule
            if type.value? value
                # If it didn't apply, the value is invalid
                rule_list.each do |rule|
                    if not rule.call value
                        valid = false
                    end 
                end
                # the value has successfully been checked
                checked = true
            end
        end

        # the value wasn't checked, so no rule was given for that value, return false
        if not checked
            return false
        end
        valid
    end

    def generate_translators
        output = [default] + (translators.keys.map { |x| x[1] }) if !default.nil?
        output = (translators.keys.map { |x| x[1] }) if default.nil?
        output.uniq.each do |out|
            converters = [Array, Hash, Integer, IO, Proc, Regexp, String]

            if converters.include? out
                a = "ary"       if out == Array
                a = "hash"      if out == Hash
                a = "int"       if out == Integer
                a = "io"        if out == IO
                a = "proc"      if out == Proc
                a = "regexp"    if out == Regexp
                a = "str"       if out == String
                
                define_method "to_#{a}" do

                    default = self.class.default
                    val = self.class.send :translate, @value.class, out, @value
                    
                    if val.nil?
                        mid = self.class.send :translate, @value.class, default, @value
                        val = self.class.send :translate, default, out, mid
                    end

                    val
                end
            end

            define_method "to_#{out.name}" do
                if @value.class == self.class
                    return @value.value
                end

                default = self.class.default

                val = self.class.send :translate, @value.class, out, @value

                if val.nil?
                    mid = self.class.send :translate, @value.class, default, @value
                    val = self.class.send :translate, default, out, mid
                end

                val
            end
        end

        numerals = [Float, Integer]
        numeral_output = numerals & output

        define_method :coerce do |other|
            # other is number that can be translated
            if numeral_output.include?(other.class)
                i = self.value(other.class)
                return [other, i]
            end

            nil
        end

    end

    def translate(d_in, d_out, value)
        if d_in == d_out
            return value
        end

        translators[[d_in, d_out]].call(value) if (!translators[[d_in, d_out]].nil? && !value.nil?)
    end

    def value=(value)
        eigen = self.class
        if eigen.compound_domain.value?(value)
            @value = value
        else
            raise ValueOutOfBoundsError.new("<#{value}> does not satisfy the rule for <#{eigen}>")
        end
    end

    def value(domain=nil)
        if !domain.nil?
            return self.instance_eval("to_#{domain}")
        else
            @value
        end
    end

    private :generate_translators, :check_rules, :translate
end

module DomainCompoundDomain
    class CompoundDomain
        def initialize(left, operand, right)
            @left = left
            @operand = operand
            @right = right
        end
    
        def value?(x)
            l = @left.value?(x)
            r = @right.value?(x)
    
            case @operand
            when :+
                return l || r
            when :&
                return l && r
            when :-
                return l && (not r)
            else
                raise ArgumentError.new "Invalid operation.  #{@operand} is not a valid operation"
            end
        end
    
        def rules
            return { left: @left.rules, operand: @operand, right: @right.rules }
        end
    
        def translators
            return { left: @left.translators, operand: @operand, right: @right.translators }
        end
    
        def translate
            l = @left.translate
        end
    end
end