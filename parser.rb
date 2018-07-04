module DomainParser
    def parse_tokens(sig)
        valid_tokens = ['(', ')', ',', '[', ']', '$', '{', '}', '&']
        sig.gsub!(/\s/, "")

        tokens = []

        other = ""
        token = ""

        state = :default
        redo_state = false

        sig.each_char do |x|
            case state
            when :default
                token += x
                case x
                when '*'
                    state = :star
                when '-'
                    state = :arrow
                when *valid_tokens
                    state = :accepted
                else
                    state = :other
                end
            when :star
                case x
                when '*'
                    state = :accepted
                    token += x
                else
                    state = :accepted
                    redo_state = true
                end
            when :arrow
                token += x
                case x
                when '>'
                    state = :accepted                   
                else
                    state = :other
                end
            end

            if state == :other
                other += token
                
                if token == ":" then state = :accepted else state = :default end
                token = ""
            end
            
            if state == :accepted
                if !other.empty? then tokens << other; other = "" end
                tokens << token if !token.empty?
                token = ""
                state = :default
            end

            if redo_state
                state = :default
                redo_state = false
                redo
            end
        end

        tokens << other if !other.empty?
        tokens
    end

    def interpret_tokens(cl, local, tokens)
        # Get tokens for arg and return separated

        k = tokens.slice_after { |x| x == '->' }.to_a
        a, r = k
        a.pop
        length = k.length

        if length != 2
            raise ArgumentError.new "Expected only one arrow (->), got #{length - 1}"
        end

        # Change the list of tokens into something more usable

        # Ignore the () if it's properly at the begnning and end
        a = a[1..-2] if a[0] == '(' && a[-1] == ')'
        r = r[1..-2] if r[0] == '(' && r[-1] == ')'

        a = retrieve_tokens(cl, local, a)
        r = retrieve_tokens(cl, local, r)[0]

        return a, r
    end

    def retrieve_tokens(cl, local, tokens)
        stack = 0
        optional = false
        arg = []
        star_prefix = 0
        state = :token
        inside = [:top]
        prev = nil
        used = {0=>{}}
        kwarg = {}
        kw = ""
        last_kws = []
        procs = false

        tokens.each do |x|
            case state
            when :token
                case x
                when '['
                    arr = arg
                    (stack).times do |i|
                        arr = arr[-1] if inside[i] != :hash
                        arr = arr[last_kws[i]] if inside[i] == :hash
                        arr = arr.domain if arr.respond_to? :domain
                    end

                    arr = arr.domain if arr.respond_to? :domain

                    if optional
                        temp_struct = Struct.new(:dollar, :domain).new
                        temp_struct.dollar = "$"
                        temp_struct.domain = []
                        arr << temp_struct if arr.class == Array
                        arr["$"] = temp_struct if arr.class == Hash
                    elsif star_prefix != 0
                        temp_struct = Struct.new(:star, :domain).new
                        temp_struct.star = "*" * star_prefix
                        temp_struct.domain = []
                        arr << temp_struct if arr.class == Array
                        arr[("*" * star_prefix)] = temp_struct if arr.class == Hash
                    else
                        arr << [] if star_prefix == 0 && arr.class == Array
                        arr[last_kws[-1]] = [] if star_prefix == 0 && arr.class == Hash
                    end

                    stack += 1
                    inside.push :array
                    star_prefix = 0
                    used[stack] = {'**' => true }
                    optional = false
                    kw = ""
                when '{'
                    arr = arg
                    (stack).times do |i|
                        arr = arr[-1] if inside[i] != :hash
                        arr = arr[last_kws[i]] if inside[i] == :hash
                        arr = arr.domain if arr.respond_to? :domain
                    end

                    arr = arr.domain if arr.respond_to? :domain

                    if optional
                        temp_struct = Struct.new(:dollar, :domain).new
                        temp_struct.dollar = "$"
                        temp_struct.domain = {}
                        arr << temp_struct if arr.class == Array
                        arr["$"] = temp_struct if arr.class == Hash
                    elsif star_prefix != 0
                        temp_struct = Struct.new(:star, :domain).new
                        temp_struct.star = "*" * star_prefix
                        temp_struct.domain = {}
                        arr << temp_struct if arr.class == Array
                        arr[("*" * star_prefix)] = temp_struct if arr.class == Hash
                    else
                        arr << {} if star_prefix == 0 && arr.class == Array
                        arr[last_kws[-1]] = {} if star_prefix == 0 && arr.class == Hash
                    end

                    stack += 1
                    inside.push :hash
                    star_prefix = 0
                    used[stack] = {'*' => true }
                    optional = false
                    kw = ""
                when ',', ']', '}'
                    raise ArgumentError.new "unexpected '#{x}' found"
                when '*', '**'
                    if star_prefix != 0 || used[stack][x] || !kw.empty? || optional
                        raise ArgumentError.new "unexpected '#{x}' found"
                    end

                    star_prefix = x.length
                    used[stack][x] = true
                when '$'
                    if optional || star_prefix != 0
                        raise ArgumentError.new "unexpected '$' found"
                    end
                    
                    optional = true
                when '&'
                    if procs || optional || star_prefix != 0
                        raise ArgumentError.new "unexpected '&' found"
                    end

                    procs = true
                else
                    if x[-1] == ":"
                        if kw.empty?
                            kw = x[0..-2]
                            kw = kw.intern

                            last_kws[stack] = kw
                        else
                            raise ArgumentError.new "unexpected keyword #{x} found"
                        end
                    elsif (k = translate_to_domain(cl, local, x)) || k.nil?
                        # If *arg or **arg exist outside of array/hash
                        if star_prefix != 0 && inside[-1] == :top
                            if star_prefix == 1
                                temp_struct = Struct.new(:star, :domain).new
                                temp_struct.star = "*"
                                temp_struct.domain = k
                                arg << temp_struct
                            end
                            kwarg['**'] = k if star_prefix == 2
                            star_prefix = 0
                        # If it's part of array or top layer and no keyword was found
                        elsif kw.empty? && inside[-1] != :hash
                            arr = arg

                            (stack).times do |i|
                                arr = arr[-1] if inside[i] != :hash
                                arr = arr[last_kws[i]] if inside[i] == :hash
                                arr = arr.domain if arr.respond_to? :domain
                            end

                            arr = arr.domain if arr.respond_to? :domain
                            if optional
                                temp_struct = Struct.new(:dollar, :domain).new
                                temp_struct.dollar = "$"
                                temp_struct.domain = k
                                arr << temp_struct
                            elsif procs
                                temp_struct = Struct.new(:ampersand, :domain).new
                                temp_struct.dollar = "&"
                                temp_struct.domain = k
                                arr << temp_struct
                            elsif star_prefix == 1
                                temp_struct = Struct.new(:star, :domain).new
                                temp_struct.star = "*"
                                temp_struct.domain = k
                                arr << temp_struct
                            elsif star_prefix == 0
                                arr << k
                            end
                             
                            star_prefix = 0
                            optional = false
                        # If its's part of hash or top and keyword was found
                        elsif !kw.empty? && inside[-1] != :array
                            if inside[-1] == :top
                                kwarg[kw] = k
                            else
                                last = arg
                                (stack).times do |i|
                                    last = last[-1] if inside[i] != :hash
                                    last = last[last_kws[i]] if inside[i] == :hash
                                    last = last.domain if last.respond_to? :domain
                                    
                                end

                                last = last.domain if last.respond_to? :domain

                                if optional
                                    temp_struct = Struct.new(:dollar, :domain).new
                                    temp_struct.dollar = "$"
                                    temp_struct.domain = k
                                    last[kw] = temp_struct
                                else
                                    last[kw] = k
                                end
                            end

                            kw = ""
                            star_prefix = 0
                            optional = false
                        # If it's part of hash and is **arg
                        elsif kw.empty? && star_prefix == 2 && inside[-1] == :hash
                            last = arg
                            (stack).times do |i|
                                last = last[-1] if inside[i] != :hash
                                last = last[last_kws[i]] if inside[i] == :hash
                                last = last.domain if last.respond_to? :domain
                            end

                            last = last.domain if last.respond_to? :domain

                            last['**'] = k

                            star_prefix = 0
                            optional = false
                            kw = ""
                        else
                            raise ArgumentError.new "could not decipher #{x}"
                        end
                        state = :comma
                    else
                        raise ArgumentError.new "could not decipher #{x}"
                    end
                end
            when :comma
                case x
                when ']'
                    if inside[-1] == :array
                        stack -= 1
                        inside.pop
                    else
                        raise ArgumentError.new "unexpected ']' found"
                    end
                when '}'
                    if inside[-1] == :hash
                        stack -= 1
                        inside.pop
                    else
                        raise ArgumentError.new "unexpected ']' found"
                    end
                when ','
                    state = :token
                else
                    a = ""
                    a = ", ']', or '}'" if stack > 1
                    raise ArgumentError.new "expected ','#{a} but found #{x}"
                end
            end
        end
        return arg, kwarg
    end


    def translate_to_domain(cl, local, sym)
        a = sym == 'nil' || sym == "%any%" || (cl.const_defined? sym.capitalize.intern) || (Object.const_defined? sym.capitalize.intern) || (local.local_variables.include? sym.downcase.intern)

        if a
            k = begin
                a = cl.const_get(sym.intern) || Object.const_get(sym.intern)

                raise ArgumentError.new "#{a} is not a domain" if !a.respond_to? :value?
                a
            rescue NameError
                if sym != 'nil' && sym != "%any%"
                    a = local.local_variable_get sym.intern

                    raise ArgumentError.new "#{a} is not a domain" if !a.respond_to? :value?
                    a   
                else
                    return sym if sym == "%any%"
                    return nil if sym == "nil"
                end
            end
        end

        k
    end

    def parse_signature(cl, local, sig)
        tokens = parse_tokens sig

        arg, ret = interpret_tokens cl, local, tokens
        return arg, ret
    end
end