# encoding: utf-8

module Utils
  #
  # Simple queue implementation (using two lists)
  # providing amortized O(1) shift and push operations.
  #
  class Queue
    def initialize(*args, &block)
      @shift_stack = args.reverse
      @push_stack  = []
      yield if block_given?
    end

    def to_a
      @shift_stack.reverse + @push_stack
    end

    # Same as push
    def <<(obj)
      push obj
    end

    def +(other)
      queue = dup
      queue.push(*other.to_a)
      queue
    end

    def empty?
      @shift_stack.empty? && @push_stack.empty?
    end

    def size
      @shift_stack.size + @push_stack.size
    end

    def shift(n = 1)
      if @shift_stack.size < n
        @shift_stack = @push_stack.reverse + @shift_stack
        @push_stack = []
      end

      popped = @shift_stack.pop(n).reverse
      popped = popped.first if n == 1

      yield popped if block_given?
      popped
    end

    def push(*args, &block)
      @push_stack += args
      if block_given?
        yield
      else
        self
      end
    end
  end
end
