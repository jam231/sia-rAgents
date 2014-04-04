# encoding: utf-8

module Serializer
	@supported_types = [:uint8, :uint16, :uint32, :utf8]

	def self.serialize values, types
		values = [values] unless values.kind_of? Array
		types = [types] unless types.kind_of? Array
 
		unless (values.size <=> types.size) == 0
			raise ArgumentError, "Value - type correspondence is invalid."
		end

		values.zip(types).flat_map do |value, type|
			send(type, value)
		end.join
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
			[int].pack('n')
		end
	end

	def self.uint32 values
		values = [values] unless values.kind_of? Array
		values.map do |int|
			raise ArgumentError, "Not an Integer" unless int.kind_of? Integer 
			[int].pack('N')
		end
	end

	# Opertion is well defined for a String or a [String]
	def self.utf8 values
		values = [values] unless values.kind_of? Array
		values.map do |str|
			raise ArgumentError, "Not a String" unless str.kind_of? String 
			serialized = str.force_encoding('utf-8')
			[uint16(serialized.bytesize), serialized].join
		end
	end
end


module Deserializer
	@supported_types = [:uint8, :uint16, :uint32, :utf8]

	# bytes_sequence : String, types : [Symbols] -> [values_arr, rest : String]
	def self.deserialize byte_sequence, types
		types = [types] unless types.kind_of? Array
	
		if byte_sequence.respond_to? :split
			byte_sequence = byte_sequence.split(//)
		elsif byte_sequence.respond_to? :to_a
			byte_sequnce = byte_sequence.to_a
		else
			raise ArgumentError "First argument neither responds to :split nor to :to_a."
		end

		values, rest = [[], byte_sequence]

		types.each do |type| 
			value, rest = send(type, rest)

			break if value.nil?
			values << value
		end
		[values, rest.join]		
	end

	# Opertion is well defined for a Integer or a [Integer]
	def self.uint16 byte_sequence
		raise ArgumentError, "First argument doesn't respond to to_a" unless byte_sequence.respond_to? :to_a
		byte_sequence = byte_sequence.to_a

		if byte_sequence.size >= 2
			[byte_sequence.take(2).join.unpack('n').first, byte_sequence.drop(2)]
		else
			[nil, byte_sequence]
		end
	end
end