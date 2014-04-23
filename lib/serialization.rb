# encoding: utf-8

module Serializer
  @supported_types = [:uint8, :uint16, :uint32, :utf8]

  def serialize values, types
    Serializer.serialize values, types
  end

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
      serialized = str.encode('utf-8').force_encoding('ASCII-8BIT')
      [uint16(serialized.bytesize), serialized].join
    end
  end
end


module Deserializer
  @supported_types = [:uint8, :uint16, :uint32, :utf8]

  def deserialize byte_sequence, types
    Deserializer.deserialize byte_sequence, types
  end

  # bytes_sequence : String, types : [Symbols] -> [values_arr, rest : String]
  def self.deserialize byte_sequence, types
    types = [types] unless types.kind_of? Array

    raise ArgumentError "First argument is not of String kind." unless byte_sequence.kind_of? String

    old_encoding = byte_sequence.encoding
    byte_sequence = byte_sequence.force_encoding('ASCII-8BIT').split(//)

    values, rest = [[], byte_sequence]

    types.each do |type|
      value, rest = send(type, rest)

      break if value.nil?
      values << value
    end
    [values, rest.join.force_encoding(old_encoding)]
  end

  # Opertion is well defined for a Integer or a [Integer]
  def self.uint8 byte_sequence
    raise ArgumentError, "First argument doesn't respond to to_a" unless byte_sequence.respond_to? :to_a
    byte_sequence = byte_sequence.to_a

    if byte_sequence.size >= 1
      [byte_sequence.take(1).join.unpack('C').first, byte_sequence.drop(1)]
    else
      [nil, byte_sequence]
    end
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

  # Opertion is well defined for a Integer or a [Integer]
  def self.uint32 byte_sequence
    raise ArgumentError, "First argument doesn't respond to to_a" unless byte_sequence.respond_to? :to_a
    byte_sequence = byte_sequence.to_a

    if byte_sequence.size >= 4
      [byte_sequence.take(4).join.unpack('N').first, byte_sequence.drop(4)]
    else
      [nil, byte_sequence]
    end
  end

  # byte_sequnce -> [deserialized : String, rest : String]
  def self.utf8 byte_sequence
    raise ArgumentError, "First argument doesn't respond to to_a" unless byte_sequence.respond_to? :to_a
    byte_sequence = byte_sequence.to_a
    length, rest = uint16 byte_sequence

    # Too few bytes, return nil and original byte_sequence
    return [nil, byte_sequence] if length.nil?

    # If there are enough bytes to read utf8 then read it
    if rest.size >= length
      utf8_candidate = rest.take(length).join

      [utf8_candidate.force_encoding('utf-8'), rest.drop(length)]
    else
      [nil, byte_sequence]
    end
  end
end
