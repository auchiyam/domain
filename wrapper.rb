require('./errors.rb')

module DomainWrapper
    include DomainErrors
    RandomSeed = Random.new(100)

    # Given a string denoting the "signature" of the method, aka the domain and codomain of the method in mathematical format,
    # wrap_method wraps the method defined right after the <domain 'signature'> call and make all argument and return values conform to signature
    def wrap_method(signature)
        # Initialization
        line = 0 # Number of lines the tracepoint parsed through
        local_binding = nil # the binding that points to the scope this domain class is called on

        trace = TracePoint.trace(:return) do |tp|
            # Counts number of returns called.  1 = return wrap_method, 2 = return domain, 3 = return method_added
            line += 1

            # Ensure that the next line of code is method defining, else this domain call is in the wrong place
            if line == 3
                if tp.method_id == :method_added || tp.method_id == :singleton_method_added
                    # Disabling the tp as soon as possible to prevent any overhead just in case
                    tp.disable

                    # parse and interpret the signature given
                    args_kwargs, ret = parse_signature self.class, local_binding, signature
                    args, kwargs = args_kwargs

                    # initialize symbols for everything
                    # ~~Get the method name we'll wrap
                    method_name = tp.binding.local_variable_get :m

                    # ~~intended to make accidental override of old method harder.  May cause a random error?
                    random = RandomSeed.rand(100000000).to_s.rjust(12, '0')

                    # ~~the temp alias
                    old_method_name = "old_#{method_name}_#{random}".intern

                    # ~~Check for validity of the method by getting its arity and aligning it with the length of arguments in signature
                    method = tp.self.instance_method(method_name) if tp.method_id == :method_added
                    method = tp.self.method(method_name) if tp.method_id == :singleton_method_added

                    # ~~Check if the parameters should have star variable (*arg) or double star variable (**arg)
                    has_star = false
                    has_dstar = false

                    args.each do |x|                        
                        has_star = true if is_star?(x) && x.star == '*'
                        has_dstar = true if is_star?(x) && x.star == '**'
                    end

                    has_dstar = !kwargs.empty? unless has_dstar

                    # Get all the parameters for the method
                    param = method.parameters
                    optional_arg = []
                    optional_kwarg = []
                    expected_length_arg = 0
                    expected_length_kwarg = 0

                    # args is nil, so there should not be any parameters except for the blocks
                    if args.length == 1 && args[0].nil? && param.reject{ |x| x[0] == :block }.length == 0
                        next
                    else
                        # Then see if the variables are structured properly, such as making sure that star variable is a 3rd variable if the signature also have star variable for 3rd
                        param_arg = param.reject { |x| x[0] != :req && x[0] != :opt && x[0] != :rest }
                        if param_arg.length != args.length
                            raise SignatureViolationError.new "Wrong number of total arguments: Expected #{args.length}, found #{param_arg.length}"
                        end
                        # Iterate every rules
                        args.zip(param).each_with_index do |x, i|
                            ar, par = x

                            # Check if the parameter is what we expected
                            case
                            when ar.class == Class
                                if par[0] != :req
                                    raise SignatureViolationError.new "Expected a required variable for #{par[1]}, found #{par[0]}"
                                end
                                expected_length_arg += 1
                            when is_star?(ar)
                                if par[0] != :rest
                                    raise SignatureViolationError.new "Expected a * variable for #{par[1]}, found #{par[0]}"
                                end
                            when is_optional?(ar)
                                optional_arg << i
                                if par[0] != :opt
                                    raise SignatureViolationError.new "Expected an optional variable for #{par[1]}, found #{par[0]}"
                                end
                                expected_length_arg += 1
                            end
                        end

                        # Do the same thing for the keyword section
                        key_matched =  []

                        param_kwarg = param.reject { |x| x[0] != :keyreq && x[0] != :key}
                        if param_kwarg.length != kwargs.length
                            raise SignatureViolationError.new "Wrong number of keyword arguments: Expected #{kwargs.length}, found #{param_kwarg.length}"
                        end
                        
                        param.each do |par|
                            if kwargs.has_key?(par[1])
                                key_matched << par[1]
                                if is_optional?(kwargs[par[1]])
                                    optional_kwarg << par[1]
                                end
                            end
                        end

                        missing = kwargs.keys - key_matched
                        missing = [] if has_dstar

                        if !missing.empty?
                            raise SignatureViolationError.new "The following keywords are not in the argument: #{missing}"
                        end
                    end

                    # determine whether to use define_method or define_singleton_method
                    use = if tp.method_id == :method_added then :define_method else :define_singleton_method end

                    tp_self = tp.self

                    # wrap the method
                    lamb = lambda do
                        tp_self.send use, method_name do | *arg1, **arg2, &block |
                            old_arg1 = arg1
                            old_arg2 = arg2

                            all_args = [pad_with_optional(arg1, optional_arg, expected_length_arg), arg2]
                            arg_types = args
                            kwarg_types = kwargs

                            if has_star
                                check_array all_args[0], arg_types
                            else
                                (all_args[0].zip(arg_types)).each do |arg_type|
                                    arg, type = arg_type
    
                                    check_validity arg, type
                                end
                            end

                            check_keyword all_args[1], kwarg_types

                            if arg1.length == 0 && arg2.length == 0
                                r = self.send(old_method_name) { block.call } if !block.nil?
                                r = self.send(old_method_name) if block.nil?
                            elsif arg2.length == 0
                                r = self.send(old_method_name, *old_arg1) { block.call } if !block.nil?
                                r = self.send(old_method_name, *old_arg1) if block.nil?
                            elsif arg1.length == 0
                                r = self.send(old_method_name, **old_arg2) { block.call } if !block.nil?
                                r = self.send(old_method_name, **old_arg2) if block.nil?
                            else
                                r = self.send(old_method_name, *old_arg1, **old_arg2) { block.call } if !block.nil?
                                r = self.send(old_method_name, *old_arg1, **old_arg2) if block.nil?
                            end

                            all_rets = if r.is_a?(Enumerable) then r else [r] end
                            ret_types = if ret.is_a?(Enumerable) then ret else [ret] end

                            all_rets.zip(ret_types).each do |ret_type|
                                ret, type = ret_type
                                
                                check_validity ret, type
                            end

                            all_rets
                        end
                    end

                    # quickly peek the next line and determine the public/private state of method
                    trace = TracePoint.trace(:line) do |tp|
                        tp.disable
                        # create the newly defined method in the appropriate places
                        if self.inspect == 'main'
                            Object.class_eval do
                                Object.alias_method(old_method_name, method_name)
                                lamb.call
                                private method_name, old_method_name
                            end
                        else
                            self.class_eval do
                                self.alias_method(old_method_name, method_name)
                                private old_method_name
                                pr = tp_self.private_methods(false).include?(method_name)
                                lamb.call
                                private method_name if pr
                            end
                        end
                    end
                else
                    tp.disable
                    raise NoMethodAddedError.new "No new method has been defined for signature '#{signature}'"
                end
            end
        end

        # Quickly grabs the binding of the scope this domain method is called on
        trace = TracePoint.trace(:line) do |tp|
            local_binding = tp.binding
            tp.disable
        end
    end

    def check_array(array, rule)
        before, after = rule.slice_after { |x| is_star?(x) && x.star == "*" }.to_a << []
        if is_star?(before[-1]) then star = before.pop else star = Struct.new(:star, :domain).new end

        # before star
        before.zip(array).each do |x|
            rule, arg = x
            check_validity arg, rule
        end

        # after star
        after.reverse.zip(array.reverse).each do |x|
            rule, arg = x
            check_validity arg, rule
        end

        # rest
        if !(star.star == nil)
            rule = star.domain
            array[before.length..((after.length+1)*-1)].each do |x|
                check_validity x, rule
            end
        else
            if !array[before.length..((after.length+1)*-1)].empty?
                raise ArgumentError.new "Invalid array. Expected length of #{before.length + after.length}, found #{array.length}"
            end
        end
    end

    def check_keyword(array, rule)
        unsolved = {}

        rule.each do |x|
            key, arg = x
            if key == '**'
                next
            end

            if array.has_key? key
                check_validity array[key], arg
            else
                unsolved[key] = arg
            end
        end

        if rule.has_key? '**'
            unsolved.each do |x|
                key, arg = x
                check_validity arg, rule['**']
            end
        end
    end

    def check_validity(val, type)
        case
        when type == nil
            raise SignatureViolationError.new "Argument value <#{val}> does not satisfy the rule for <nil>" if !val.nil?
        when type == '%any%'
            return
        when is_optional?(type)
            if !val.nil?
                check_validity(val, type.domain)
            end
        when type.class == Array
            if val.is_a? Array
                check_array(val, type)
            else
                raise SignatureViolationError.new "Argument value <#{val}> does not satisfy the rule for <#{type}>"
            end
        when type.class == Hash
            if val.is_a? Hash
                check_keyword(val, type)
            else
                raise SignatureViolationError.new "Argument value <#{val}> does not satisfy the rule for <#{type}>"
            end
        when !type.value?(val)
            raise SignatureViolationError.new("Argument value <#{val}> does not satisfy the rule for <#{type}>")
        when type == nil && val != nil
            raise SignatureViolationError.new("Return value <#{ret}> does not satisfy the rule for <nil>")
        end
    end

    def pad_with_optional(args, optional_index, expected_length)
        (optional_index.length - (expected_length - args.length)).times do
            optional_index.shift
        end
        optional_index.each do |x|
            args.insert(x, nil)
        end

        args
    end
    
    def is_star?(check)
        check.respond_to?(:members) && check.members == [:star, :domain]
    end

    def is_optional?(check)
        check.respond_to?(:members) && check.members == [:dollar, :domain]
    end
end