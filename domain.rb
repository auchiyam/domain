require('./wrapper.rb')
require('./parser.rb')
require('./domain_class.rb')
require('./monkey_patching.rb')
require('./create_domain.rb')
require('./errors.rb')

module Domain
    extend self
    include DomainCreate
    include DomainWrapper
    include DomainParser
    include DomainCompoundDomain
    include DomainCreate
    include DomainErrors

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
                c = create_domain(name: a) do
                    yield
                end

                create_initializer a, c

                c
            elsif a.is_a? String
                wrap_method(a)
            else
                raise ArgumentError.new "domain is not defined for argument: (#{a.class})"
            end
        else
            raise ArgumentError.new "domain is not defined for #{arg.length} argument(s)"
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