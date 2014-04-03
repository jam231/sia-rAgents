# encoding: utf-8

module Serializer
	@supported_types = [:uint8, :uint16, :uint32, :utf8]

	def serialize values, types
		values = [values] unless values.kind_of? Array
		types = [types] unless types.kind_of? Array
 
		unless (values.size <=> types.size) == 0
			raise ArgumentError, "Value - type correspondence is invalid."
		end

		values.zip(types).collect do |value, type|
			send(type, value)
		end.flatten
	end

	def uint8 values
	end

	def uint16 values
	end

	def uint32 values
	end

	# Opertion is well defined for a string or a [string]
	def utf8 values
		values = [values] unless values.kind_of? Array
		values.map do |str|
			raise ArgumentError, "Not a string" unless str.kind_of? String 
			str.bytes.to_a.pack('U*')
		end
	end
end


