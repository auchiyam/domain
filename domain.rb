require('./wrapper.rb')
require('./parser.rb')
require('./domain_class.rb')
require('./monkey_patching.rb')

module Domain
    extend self
    include DomainWrapper
    include DomainParser
    include DomainCompoundDomain
    class Error < StandardError; end
    class ValueOutOfBoundsError < Error; end
    class InvalidRuleError < Error; end
    class InvalidSignatureError < Error; end
    class NoMethodAddedError < Error; end
    class SignatureViolationError < Error; end
    class NoTranslationError < Error; end

    # The entrance to most of the domain logic in the library
    def domain(*arg)
        case arg.length
        when 0
            create_domain do
                yield
            end
        when 1
            a = arg[0]

            if a.is_a? Symbol
                create_domain(name: a) do
                    yield
                end
            elsif a.is_a? String
                wrap_method(a)
            else
                raise ArgumentError.new "domain is not defined for argument: (#{a.class})"
            end
        else
            raise ArgumentError.new "domain is not defined for #{arg.length} argument(s)"
        end
    end

    # Given a block of rules and optionally a compound rule, create_domain create an anonymous class
    # that is based on the template
    def create_domain(compound: 0, name: "")
        if !block_given? && compound == 0
            raise ArgumentError.new "No block of rules were given.  There must be at least one rule for the domain"
        end

        # create a new class
        cl = Class.new do
            extend DomainClass   
            include DomainClass
        end

        # prevents override of domain_created when nested.  Returns the @domain_created to the previous one after everything is done
        prev = @domain_created

        # set the domain that is currently being created
        @domain_created = cl

        # Initialization
        # set the compound_domain to the specified one if it has any, else assign itself as compound domain
        @domain_created.compound_domain = unless compound == 0 then compound else @domain_created end
        @domain_created.rules = {}
        @domain_created.translators = {}
        @domain_created.default = nil

        # Read blocks for the rules and other initialization
        yield if block_given?

        # since setup that takes place outside of this scope is done, revert it to the original
        @domain_created = prev

        # generate all the "to_<Domain>" methods based on the translators
        cl.send :generate_translators

        # If the name was provided, create the constant with that name
        if not name.empty?
            if self.inspect == 'main'
                Object.const_set(name, cl)
            else
                self.const_set(name, cl)
            end
        # else, the domain should be anonymous
        else
            return cl
        end
    end

    # If domain was given, set the block as the rule for the domain, else, set the domain to nil so that the rule is checked for everything
    def rule(domain=nil, &rule)
        # check if the domain given is actually a domain
        if !domain.respond_to?(:value?) && domain != nil
            raise ArgumentError.new "#{domain} is not a domain."
        end

        # Initialize a new array for the domain if it does not exist
        if @domain_created.rules[domain] == nil
            @domain_created.rules[domain] = []
        end

        # If the domain was specified and block was empty, just say that everything in that domain is accepted
        if domain != nil && rule == nil
            @domain_created.rules[domain] << Proc.new { |x| true }
            return
        end

        # Add the rule to the domain.  If the domain was not specified, it will apply to all variables
        if rule != nil
            @domain_created.rules[domain] << rule
            return
        end

        raise InvalidRuleError.new "The rule created does not fit the criteria.  There must be either a domain or a rule"
    end

    # Given a value that reside in domain, the block should specify exactly how the value should translate into other values
    def translation(domain_in, domain_out, &rule)
        # Check if the domain specified are domain
        if !domain_in.respond_to?(:value?) && domain_in != :default
            domain_in = "nil" if domain_in == nil
            raise ArgumentError.new "#{domain_in} is not a domain."
        end

        if !domain_out.respond_to?(:value?) && domain_out != :default
            domain_out = "nil" if domain_out == nil
            raise ArgumentError.new "#{domain_out} is not a domain."
        end

        # Check if the the translation use the default.  If it does, then make sure if the default exist.
        if domain_in == :default && @domain_created.default.nil?
            raise ArgumentError.new "Default for this domain does not exist"
        end

        if domain_out == :default && @domain_created.default.nil?
            raise ArgumentError.new "Default for this domain does not exist"
        end

        # Swap the domain to the default value if it was asked for
        domain_in = @domain_created.default if domain_in  == :default
        domain_out = @domain_created.default if domain_out == :default

        @domain_created.translators[[domain_in, domain_out]] = rule
    end

    # Convenient way to set a "default" form of value to translate to and from
    def default(domain)
        # Check if the domain given is the domain
        if !domain.respond_to?(:value?) || domain == nil
            domain = "nil" if domain == nil
            raise ArgumentError.new "#{domain} is not a domain."
        end

        @domain_created.default = domain
    end

    # private methods
    # ~~For domain
    private :create_domain
    # ~~For domain_class module
    # ~~For parser module
    private :parse_signature, :parse_tokens, :interpret_tokens, :translate_to_domain
    # ~~For wrapper module
    private :wrap_method, :check_array, :check_keyword, :check_validity, :pad_with_optional, :is_optional?, :is_star?

end