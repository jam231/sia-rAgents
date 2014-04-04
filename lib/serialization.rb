# encoding: utf-8

module Serializer
	@supported_types = [:uint8, :uint16, :uint32, :utf8]

	# TODO 
	def self.serialize values, types
		values = [values] unless values.kind_of? Array
		types = [types] unless types.kind_of? Array
 
		unless (values.size <=> types.size) == 0
			raise ArgumentError, "Value - type correspondence is invalid."
		end

		u = values.zip(types).map do |value, type|
			send(type, value)
		end.flatten.join
	end

	# Opertion is well defined for a Integer or a [Integer]
	def self.uint8 values
		values = [values] unless values.kind_of? Array
		values.map do |int|
			raise ArgumentError, "Not an Integer" unless int.kind_of? Integer 
			[int].pack('C')
		end
	end

	# Opertion is well defined for a Integer or a [Integer]
	def self.uint16 values
		values = [values] unless values.kind_of? Array
		values.map do |int|
			raise ArgumentError, "Not an Integer" unless int.kind_of? Integer 
			[int].pack('S')
		end
	end

	def self.uint32 values
		values = [values] unless values.kind_of? Array
		values.map do |int|
			raise ArgumentError, "Not an Integer" unless int.kind_of? Integer 
			[int].pack('L')
		end
	end

	# Opertion is well defined for a String or a [String]
	def self.utf8 values
		values = [values] unless values.kind_of? Array
		values.map do |str|
			raise ArgumentError, "Not a String" unless str.kind_of? String 
			str.bytes.to_a.pack('U*')
		end
	end
end


