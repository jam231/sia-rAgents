# encoding: utf-8
require_relative 'serialization.rb'



def drop_bytes(data, length)
	old_encoding = data.encoding
	data.force_encoding('ASCII-8BIT').split(//).drop(length).join.force_encoding(old_encoding)
end


#  TODO:
#  		- Warn overriding module
# 		- Warn (or even throw exception) when overriding existing method.


module SiaNetworkProtocol
	def request_for(klass, args)
		_, fields_types, * = args.fetch(:body, []).transpose
		name, type = args[:name].to_sym, args[:type]
		klass.instance_eval do 
			define_method(name) do |*args|	
				body =  if fields_types.nil? || fields_types.empty? then "" else serialize args, fields_types end
				serialized_type  = serialize type, :uint8
				length = serialize (body.bytesize + serialized_type.bytesize + 2), :uint16	
				[length, serialized_type, body].join
			end 
		end
	end

	def define_requests(module_name)
		requests_module = Module.new do
			include Serializer
			private :serialize
		end
		Object.const_set(module_name, requests_module)
		yield requests_module
	end

	# Function given by block should either return [values, remaining_data] 
	# or [:response_dropped, data] if supplied data is, for some reason, invalid.
	def custom_deserializer_for(klass, type, &block)
		klass.instance_eval do 
			@@custom_deserializers[type] = Proc.new &block
		end
	end

	def response_for(klass, args)
		fields, fields_types, * = args.fetch(:body,[]).transpose
		raise "body of response is invalid." unless (fields.nil? and fields_types.nil?) || fields.size == fields_types.size 
		name, type = args[:name].to_sym, args[:type]
		raise "from_data name is reserved!" unless name != :from_data
		klass.instance_eval do 
			@@response_deserializers[type] = name
			# if there is too few bytes to read message then return [:not_enough_bytes, data]
			# otherwise deserialize message  and return [[response_name, [field_name => value,..]], rest_of_data]
			define_method(name) do |data|
				unless fields.nil? || fields.empty? 
					values, rest_of_data = [], data
					fields_types.each do |type| 
						custom = @@custom_deserializers[type]
						value, rest_of_data = if custom.nil? then deserialize data, type 
											  				 else custom.call(data) end
						break if value.empty?
						values += value
					end

					if values.size == fields.size
						[[name, Hash[fields.zip(values)]], rest_of_data]
					else
						[:not_enough_bytes, data]
					end
				else
					[[name], data ]
				end 	
			end 
		end
	end

	def define_responses(module_name)
		responses_module = Module.new do
			include Deserializer			
			@@response_deserializers = Hash.new(:unrecognized_response)
			@@custom_deserializers   = {}
			private :deserialize
			
			def unrecognized_response data
				puts "Unrecognized message with body =  #{data.inspect}"
				[[:unrecognized_response], data]
			end
		end
		Object.const_set(module_name, responses_module)
		yield responses_module
		
		# Now, when we have the knowledge off all responses we can write 
		# function for deserialization
		responses_module.instance_eval do

			define_method(:from_data) do |data|
				values, rest =  deserialize data, :uint16
				if values.empty? or data.bytesize < values.first
					return [:not_enough_bytes, data] 
				else
					length = values.first
					# At this moment it does not matter if data is corrupted, 
					# length bytes will be dropped from data
					truncated_data = drop_bytes(data, length)
					response = :response_dropped

					type, rest = deserialize rest, :uint8
					response, _ = send(@@response_deserializers[type.first], rest)
					response = :response_dropped if response == :not_enough_bytes
					
					[response, truncated_data]
				end
			end
		end
	end
end
