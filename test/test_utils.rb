# encoding: utf-8

require_relative '../lib/utils.rb'
require_relative 'test_helper.rb'

require 'test/unit'

class TestQueue < Test::Unit::TestCase

	def test_shift_empty
		queue = Utils::Queue.new
		assert_equal nil, queue.shift
	end

	def test_shift_one
		queue = Utils::Queue.new 1
		assert_equal 1, queue.shift
	end

	def test_shift_two
		queue = Utils::Queue.new 1,2
		assert_equal 1, queue.shift
	end

	def test_shift_multishift_two
		queue = Utils::Queue.new 1
		assert_equal [1], queue.shift(2)
	end

	def test_shift_multishift_two
		queue = Utils::Queue.new 1,2,3
		assert_equal [1, 2], queue.shift(2)
	end

	def test_push_shift_one
		queue = Utils::Queue.new
		queue.push 1
		assert_equal 1, queue.shift
	end

	def test_push_shift_multi
		queue = Utils::Queue.new
		queue.push 1,2,3
		assert_equal [1, 2], queue.shift(2)
	end

	def test_to_a_empty
		queue = Utils::Queue.new
		assert_equal [], queue.to_a
	end

	def test_to_a_two_elements
		queue = Utils::Queue.new 1,2
		assert_equal [1,2], queue.to_a
	end

	def test_plus_array
		queue = Utils::Queue.new 1,2
		assert_equal [1,2,3,4], (queue + [3,4]).to_a
	end

	def test_plus_queue
		queue1 = Utils::Queue.new 1,2
		queue2 = Utils::Queue.new 3,4,5
		assert_equal [1,2,3,4,5], (queue1 + queue2).to_a
	end

	def test_plus_queue_immutability
		queue1 = Utils::Queue.new 1,2
		queue2 = Utils::Queue.new 3,4,5
		
		queue1 + queue2

		assert_equal [1,2], queue1.to_a
		assert_equal [3,4,5], queue2.to_a
	end

	def test_size_empty
		queue = Utils::Queue.new

		assert_equal 0, queue.size
	end

	def test_size_many_elements_1
		arr = (1..25).to_a
		queue = Utils::Queue.new *arr

		assert_equal arr.size, queue.size
	end

	def test_size_many_elements_2
		arr = (1..25).to_a
		queue = Utils::Queue.new.push *arr

		assert_equal arr.size, queue.size
	end

	def test_empty_on_empty
		queue = Utils::Queue.new

		assert_equal true, queue.empty?
	end

	def test_empty_on_many_elements_1
		arr = (1..25).to_a
		queue = Utils::Queue.new *arr

		assert_equal false, queue.empty?
	end

	def test_empty_on_many_elements_2
		arr = (1..25).to_a
		queue = Utils::Queue.new.push *arr

		assert_equal false, queue.empty?
	end
end