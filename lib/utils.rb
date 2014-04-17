# encoding: utf-8


module Utils

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
			self.push obj
		end

		def +(collection)
			queue = self.dup
			queue.push *collection.to_a
			queue
		end

		def empty?
			@shift_stack.empty? and @push_stack.empty?
		end

		def size
			@shift_stack.size + @push_stack.size
		end

		def shift(n=1)
			if @shift_stack.size < n
				@shift_stack = @push_stack.reverse + @shift_stack
				@push_stack = []
			end

			popped = @shift_stack.pop(n).reverse
			popped = popped.first if n == 1

			if block_given?
				yield popped 
			else
				popped
			end
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