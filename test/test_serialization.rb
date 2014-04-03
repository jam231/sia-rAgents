# encoding: utf-8

require_relative '../lib/serialization.rb'
require 'test/unit'

include Serializer

class TestSerializationUtf8 < Test::Unit::TestCase
	def test_empty_string
		assert_equal "", Serializer::serialize("", :utf8).first	
	end

	def test_ascii_string
		assert_equal "sample text".bytes.to_a.pack('U*'), Serializer::serialize("sample text", :utf8).first
	end

	def test_utf8_string
		assert_equal "tąśćt".bytes.to_a.pack('U*'), Serializer::serialize("tąśćt", :utf8).first
	end

	def test_typecheck_integer
		assert_raise(ArgumentError) { Serializer::serialize(4, :utf8) }
	end

	def test_typecheck_array1
		assert_raise(ArgumentError) { Serializer::serialize([1], :utf8) }
	end

	def test_typecheck_array2
		assert_raise(ArgumentError) { Serializer::serialize(["test string", "54535"], :utf8) }
	end

	def test_typecheck_array3
		assert_raise(ArgumentError) { Serializer::serialize(["test string", 4], :utf8) }
	end
end

class TestSerializetionUint8 < Test::Unit::TestCase
	def test_zero
		assert_equal [0].pack('C'), Serializer::serialize(0, :uint8).first	
	end

	def test_one
		assert_equal [1].pack('C'), Serializer::serialize(1, :uint8).first
	end

	def test_max_value
		value = 1 << 8 - 1
		assert_equal [value].pack('C'), Serializer::serialize(value, :uint8).first
	end

	def test_typecheck_string
		assert_raise(ArgumentError) { Serializer::serialize("test string", :uint8) }
	end

	def test_typecheck_array1
		assert_raise(ArgumentError) { Serializer::serialize([4,4], :uint8) }
	end

	def test_typecheck_array2
		assert_raise(ArgumentError) { Serializer::serialize([4, "fdsdfdsf"], :uint8) }
	end

	def test_typecheck_array3
		assert_raise(ArgumentError) { Serializer::serialize(["test string", 4], :uint8) }
	end
end



