# encoding: utf-8

require_relative '../lib/serialization.rb'
require 'test/unit'

class TestSerializationUtf8 < Test::Unit::TestCase
	def test_empty_string
		serialized_text = "".force_encoding('utf-8')
		length = [serialized_text.size].pack('n')
		assert_equal [length, serialized_text].join,  Serializer.serialize("", :utf8)
	end

	def test_ascii_string
		serialized_text = "sample text".force_encoding('utf-8')
		length = [serialized_text.size].pack('n')
		assert_equal [length, serialized_text].join, Serializer.serialize("sample text", :utf8)
	end

	def test_utf8_string
		serialized_text = "tąśćt".force_encoding('utf-8')
		length = [serialized_text.bytesize].pack('n')
		assert_equal [length, serialized_text].join, Serializer.serialize("tąśćt", :utf8)
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
		assert_equal [0].pack('n'), Serializer.serialize(0, :uint16)
	end

	def test_one
		assert_equal [1].pack('n'), Serializer.serialize(1, :uint16)
	end

	def test_max_value
		value = 1 << 16 - 1
		assert_equal [value].pack('n'), Serializer.serialize(value, :uint16)
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
		assert_equal [0].pack('N'), Serializer.serialize(0, :uint32)
	end

	def test_one
		assert_equal [1].pack('N'), Serializer.serialize(1, :uint32)
	end

	def test_max_value
		value = 1 << 32 - 1
		assert_equal [value].pack('N'), Serializer.serialize(value, :uint32)
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

class TestDeserializationUtf8 < Test::Unit::TestCase
	def test_empty_string
		serialized = "".force_encoding('utf-8')
		length = [serialized.bytesize].pack('n')
		byte_sequence = [length, serialized].join
		assert_equal [[""], ""], Deserializer.deserialize(byte_sequence, :utf8) 
	end

	def test_ascii_string
		serialized = "sample text".force_encoding('utf-8')
		length = [serialized.bytesize].pack('n')
		byte_sequence = [length, serialized].join
		
		assert_equal [["sample text"], ""], Deserializer.deserialize(byte_sequence, :utf8)
	end

	def test_utf8_string
		serialized = "ąść".force_encoding('utf-8')
		length = [serialized.bytesize].pack('n')
		byte_sequence = [length, serialized].join

		assert_equal [["ąść"], ""], Deserializer.deserialize(byte_sequence, :utf8)
	end

	def test_utf8_two_strings
		serialized = "tąśćt".force_encoding('utf-8')
		length = [serialized.bytesize].pack('n')
		byte_sequence = [length, serialized, length, serialized].join
		assert_equal [["tąśćt", "tąśćt"], ""], Deserializer.deserialize(byte_sequence, [:utf8, :utf8])
	end

	def test_length_mismatch_string_too_short
		serialized = "sample text".force_encoding('utf-8')
		length = [serialized.bytesize - 2].pack('n')
		byte_sequence = [length, serialized].join
		rest = "xt".bytes.to_a.pack('U*')
	
		assert_equal [["sample te"], rest], Deserializer.deserialize(byte_sequence, :utf8)
	end

	def test_length_mismatch_string_too_long
		serialized = "sample text".force_encoding('utf-8')
		length = [serialized.bytesize + 2].pack('n')
		byte_sequence = [length, serialized].join

		assert_equal [[], byte_sequence], Deserializer.deserialize(byte_sequence, :utf8)
	end
end


class TestDeserializationUint16 < Test::Unit::TestCase
	def test_zero
		serialized = [0].pack('n')
		assert_equal [[0], ""], Deserializer.deserialize(serialized, :uint16)
	end

	def test_one
		serialized = [1].pack('n')
		assert_equal [[1], ""], Deserializer.deserialize(serialized, :uint16)
	end

	def test_max_value
		max_value = 1 << 16 - 1
		serialized = [max_value].pack('n')
		
		assert_equal [[max_value], ""], Deserializer.deserialize(serialized, :uint16)
	end

	def test_one_byte_sequence
		serialized = [1].pack('C')

		assert_equal [[], serialized], Deserializer.deserialize(serialized, :uint16)
	end

	def test_two_uint16
		max_value = 1 << 16 - 1
		byte_sequence = [max_value, max_value].pack('n*')

		assert_equal [[max_value, max_value], ""], Deserializer.deserialize(byte_sequence, [:uint16, :uint16])
	end

	def test_two_uint16_2
		max_value = 1 << 16 - 1
		byte_sequence = [max_value, max_value].pack('n')
		rest = byte_sequence.slice(2..byte_sequence.size)
		assert_equal [[max_value], rest], Deserializer.deserialize(byte_sequence, [:uint16])
	end
end


class TestDeserializationUint8 < Test::Unit::TestCase
	def test_zero
		serialized = [0].pack('C')
		assert_equal [[0], ""], Deserializer.deserialize(serialized, :uint8)
	end

	def test_one
		serialized = [1].pack('C')
		assert_equal [[1], ""], Deserializer.deserialize(serialized, :uint8)
	end

	def test_max_value
		max_value = 1 << 8 - 1
		serialized = [max_value].pack('C')
		
		assert_equal [[max_value], ""], Deserializer.deserialize(serialized, :uint8)
	end

	def test_empty_sequence
		serialized = ""

		assert_equal [[], serialized], Deserializer.deserialize(serialized, :uint8)
	end

	def test_two_uint8
		max_value = 1 << 8 - 1
		byte_sequence = [max_value, max_value].pack('C*')

		assert_equal [[max_value, max_value], ""], Deserializer.deserialize(byte_sequence, [:uint8, :uint8])
	end

	def test_two_uint8_2
		max_value = 1 << 8 - 1
		byte_sequence = [max_value, max_value].pack('C*')
		rest = byte_sequence.slice(1..byte_sequence.size)
		
		assert_equal [[max_value], rest], Deserializer.deserialize(byte_sequence, [:uint8])
	end
end


class TestDeserializationUint32 < Test::Unit::TestCase
	def test_zero
		serialized = [0].pack('N')
		assert_equal [[0], ""], Deserializer.deserialize(serialized, :uint32)
	end

	def test_one
		serialized = [1].pack('N')
		assert_equal [[1], ""], Deserializer.deserialize(serialized, :uint32)
	end

	def test_max_value
		max_value = 1 << 32 - 1
		serialized = [max_value].pack('N')
		
		assert_equal [[max_value], ""], Deserializer.deserialize(serialized, :uint32)
	end

	def test_empty_sequence
		serialized = ""

		assert_equal [[], serialized], Deserializer.deserialize(serialized, :uint32)
	end

	def test_two_uint32
		max_value = 1 << 32 - 1
		byte_sequence = [max_value, max_value].pack('N*')

		assert_equal [[max_value, max_value], ""], Deserializer.deserialize(byte_sequence, [:uint32, :uint32])
	end

	def test_two_uint8_2
		max_value = 1 << 32 - 1
		byte_sequence = [max_value, max_value].pack('N*')
		rest = byte_sequence.slice(4..byte_sequence.size)
		
		assert_equal [[max_value], rest], Deserializer.deserialize(byte_sequence, [:uint32])
	end
end