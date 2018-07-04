module Util
    def make_compound_domain(symbol)
        define_method symbol do |x|
            dom = Domain.send :create_domain, compound: Domain::CompoundDomain.new(self, symbol, x)

            line = 0

            tp = TracePoint.trace(:return) do |x|
                line += 1

                # 1: exit compounding, 2: outside
                if line == 2
                end
            end

            dom
        end
    end
end

class Object
    class << self
        include Util
        def rules
            [{ self => Proc.new { |x| true } }]
        end

        def compound_domain
            self
        end

        def translators
            {}
        end

        def value?(x)
            return x.is_a? self
        end

        def has_compound_domain
            self != compound_domain
        end

        def method_added(m)
            super
        end

        def singleton_method_added(m)
            super
        end

        make_compound_domain :+
        make_compound_domain :-
        make_compound_domain :&

        alias :union :+
        alias :intersect :&
        alias :difference :-
    end

    def part_of?(x)
        if x.singleton_methods.include? :value?
            x.value? self
        end

        raise TypeError.new("#{x} is not a domain.")
    end

    def value
        return self
    end
end