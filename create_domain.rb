require('./errors.rb')

module DomainCreate
    include DomainErrors
    extend self
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

    def create_initializer(a, domain)
        line = 0

        tp = TracePoint.trace(:line) do |x|
            line += 1

            if line == 2
                bind = x.binding

                if x.self.inspect != "main"
                    x.self.class_eval do
                        DomainCreate::define_initializer a, domain
                    end
                else
                    Object.class_eval do
                        DomainCreate::define_initializer a, domain
                    end
                end

                x.disable
            end
        end
    end

    def define_initializer(a, domain)
        define_method a do |sym|
            layer = 1
            bind = nil
            obj_id = 8
            line_checked = 0
            path_checked = 0

            line_trace = TracePoint.trace(:line) do |x|
                # do this after the bind has successfully been retrieved
                if bind != nil
                    # Get the obj ID of the value
                    new_obj_id = 0
                    value = bind.local_variable_get(sym) if bind.local_variable_defined?(sym)
                    new_obj_id = value.object_id if bind.local_variable_defined?(sym)

                    # If the ID changed, then a new value was assigned to the variable.  Check for validity
                    if new_obj_id != obj_id
                        if !domain.value? value
                            raise ValueOutOfBoundsError.new "from #{path_checked}:#{line_checked}: '#{value}' assigned to variable '#{sym}', which is out of bounds from '#{domain.name}'"
                        end

                        val = domain.new
                        val.value = value

                        bind.local_variable_set(sym, val)

                        # update obj_id
                        obj_id = new_obj_id
                    end

                    path_checked = x.path
                    line_checked = x.lineno
                else
                    next
                end
            end

            # A method was called within the block, disable the line logic for efficiency
            call_trace = TracePoint.trace(:call) do |x|
                line_trace.disable if line_trace.enabled?

                layer += 1
            end


            # The method has ended, so remove a layer.  If it returned to the original layer, resume the line logic
            # Additionally, if it reach -1 layer, then it is outside the method.  Disable all trace
            return_trace = TracePoint.trace(:return) do |x|
                layer -= 1

                if layer == 0
                    line_trace.enable
                end

                if layer == -1
                    line_trace.disable
                    x.disable
                    call_trace.disable
                end
            end

            bind_trace = TracePoint.trace(:line) do |x|
                bind = x.binding
                bind_trace.disable
            end
        end
    end
end