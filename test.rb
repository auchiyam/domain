class T
    def create_tracepoint
        value = "value"
        line = 0

        line_even = TracePoint.trace(:line) do |x|
            puts value
        end

        line_odd = TracePoint.trace(:line) do |x|
            line += 1
            puts line
            if line == 2
                line_even.disable
            end

            if line == 3
                line_even.enable
                line_odd.disable
            end
        end

    end
end

def buffer
end

a = T.new

a.create_tracepoint

buffer
buffer
buffer
buffer
buffer