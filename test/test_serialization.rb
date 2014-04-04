# encoding: utf-8

require_relative '../lib/serialization.rb'
require 'test/unit'

class TestSerializationUtf8 < Test::Unit::TestCase
	def test_empty_string
		assert_equal "", Serializer.serialize("", :utf8)
	end

	def test_ascii_string
		assert_equal "sample text".bytes.to_a.pack('U*'), Serializer.serialize("sample text", :utf8)
	end

	def test_utf8_string
		assert_equal "tąśćt".bytes.to_a.pack('U*'), Serializer.serialize("tąśćt", :utf8)
	end

	def test_typecheck_integer
		assert_raise(ArgumentError) { Serializer.serialize(4, :utf8) }
	end

	def test_typecheck_array1
		assert_raise(ArgumentError) { Serializer.serialize([1], :utf8) }
	end

	def test_typecheck_array2
		assert_raise(ArgumentError) { Serializer.serialize(["test string", "54535"], :utf8) }
	end

	def test_typecheck_array3
		assert_raise(ArgumentError) { Serializer.serialize(["test string", 4], :utf8) }
	end
end

class TestSerializetionUint8 < Test::Unit::TestCase
	def test_zero
		assert_equal [0].pack('C'), Serializer.serialize(0, :uint8)
	end

	def test_one
		assert_equal [1].pack('C'), Serializer.serialize(1, :uint8)
	end

	def test_max_value
		value = 1 << 8 - 1
		assert_equal [value].pack('C'), Serializer.serialize(value, :uint8)
	end

	def test_typecheck_string
		assert_raise(ArgumentError) { Serializer.serialize("test string", :uint8) }
	end

	def test_typecheck_array1
		assert_raise(ArgumentError) { Serializer.serialize([4,4], :uint8) }
	end

	def test_typecheck_array2
		assert_raise(ArgumentError) { Serializer.serialize([4, "fdsdfdsf"], :uint8) }
	end

	def test_typecheck_array3
		assert_raise(ArgumentError) { Serializer.serialize(["test string", 4], :uint8) }
	end
end


class TestSerializetionUint16 < Test::Unit::TestCase
	def test_zero
		assert_equal [0].pack('S'), Serializer.serialize(0, :uint16)
	end

	def test_one
		assert_equal [1].pack('S'), Serializer.serialize(1, :uint16)
	end

	def test_max_value
		value = 1 << 16 - 1
		assert_equal [value].pack('S'), Serializer.serialize(value, :uint16)
	end

	def test_typecheck_string
		assert_raise(ArgumentError) { Serializer.serialize("test string", :uint16) }
	end

	def test_typecheck_array1
		assert_raise(ArgumentError) { Serializer.serialize([4,4], :uint16) }
	end

	def test_typecheck_array2
		assert_raise(ArgumentError) { Serializer.serialize([4, "fdsdfdsf"], :uint16) }
	end

	def test_typecheck_array3
		assert_raise(ArgumentError) { Serializer.serialize(["test string", 4], :uint16) }
	end
end


class TestSerializetionUint32 < Test::Unit::TestCase
	def test_zero
		assert_equal [0].pack('L'), Serializer.serialize(0, :uint32)
	end

	def test_one
		assert_equal [1].pack('L'), Serializer.serialize(1, :uint32)
	end

	def test_max_value
		value = 1 << 32 - 1
		assert_equal [value].pack('L'), Serializer.serialize(value, :uint32)
	end

	def test_typecheck_string
		assert_raise(ArgumentError) { Serializer.serialize("test string", :uint32) }
	end

	def test_typecheck_array1
		assert_raise(ArgumentError) { Serializer.serialize([4,4], :uint32) }
	end

	def test_typecheck_array2
		assert_raise(ArgumentError) { Serializer.serialize([4, "fdsdfdsf"], :uint32) }
	end

	def test_typecheck_array3
		assert_raise(ArgumentError) { Serializer.serialize(["test string", 4], :uint32) }
	end
end