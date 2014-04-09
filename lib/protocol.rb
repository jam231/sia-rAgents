# encoding: utf-8
require_relative 'protocol_helper.rb'

# FIXME: This include below is ugly
include SiaNetworkProtocol

define_requests("Requests") do |requests|
	request_for requests, :name => :register_me, 	:type => 0x0, :body => [[:password, :utf8]]
	request_for requests, :name => :login_me, 		:type => 0x4, 
						  :body => [[:user_id,  :uint32], [:password, :utf8]]
	request_for requests, :name => :get_my_stocks, :type => 0x1d
	request_for requests, :name => :get_my_orders, :type => 0x1f
	request_for requests, :name => :buy_stock, 		:type => 0x15, 
						  :body => [[:stock_id, :uint32], [:amount, :uint32], [:price, :uint32]]
	request_for requests, :name => :sell_stock, 	:type => 0x14, 
						  :body => [[:stock_id, :uint32], [:amount, :uint32], [:price, :uint32]]
	request_for requests, :name => :cancel_order, 	:type => 0x23, 
						  :body => [[:order_id, :uint32]]
	request_for requests, :name => :get_stock_info, :type => 0x21, 
						  :body => [[:stock_id, :uint32]]
	request_for requests, :name => :subscribe, :type => 0x1b, 
						  :body => [[:stock_id, :uint32]]
	request_for requests, :name => :unsubscribe, :type => 0x1c, 
						  :body => [[:stock_id, :uint32]]
end

define_responses("Responses") do |responses|
	response_for responses, :name => :ok, 	:type => 0x2
	response_for responses, :name => :fail, :type => 0x3, :body => [[:status, :uint8]]
	response_for responses, :name => :order_accepted, :type => 0x24, :body => [[:order_id, :uint32]]
	response_for responses, :name => :order_change, :type => 0x17, 
							:body => [[:order_id, :uint32], [:amount, :uint32], [:price, :uint32]]
	response_for responses, :name => :order_completed, :type => 0x16, 
							:body => [[:order_id, :uint32]]

	response_for responses, :name => :show_best_order,:type => 0x1a, 
							:body => [[:order_typr, :uint8], [:stock_id, :uint32], [:amount, :uint32], [:price, :uint32]]

	response_for responses, :name => :list_of_stocks, :type => 0x1e, :body => [[:stocks, :list_of_stocks]]
	response_for responses, :name => :list_of_orders, :type => 0x20, :body => [[:orders, :list_of_orders]]
	response_for responses, :name => :register_successful, :type => 0x1, :body => [[:user_id, :uint32]]
	# This list is incomplete, there are couple messages not included here, but used (6-04-2014) by sia server.
	#...

	custom_deserializer_for responses, :list_of_orders do |data|
		(obj_count, _), rest = Deserializer.deserialize data, :uint16
		if obj_count.nil? or rest.bytesize < (obj_count * 17)	# single order data is 17 bytes long
			[:response_dropped, data]
		else
			orders = []
			order_fields = [:order_id, :order_type, :stock_id, :amount, :price]
			obj_count.times do
				order_values, rest = Deserializer.deserialize rest, [:uint32, :uint8, :uint32, :uint32, :uint32] 
				orders << Hash[order_fields.zip(order_values)] 
			end
			[orders, rest]
		end
	end

	custom_deserializer_for responses, :list_of_stocks do |data|
		(obj_count, _), rest = Deserializer.deserialize data, :uint16
		if obj_count.nil? or rest.bytesize < (obj_count * 8)	# single stock list entry is 8 bytes long
			[:response_dropped, data]
		else
			user_stocks = []
			stock_fields = [:stock_id, :amount]
			obj_count.times do 
				stock_values, rest = Deserializer.deserialize rest, [:uint32, :uint32] 
				user_stocks << Hash[stock_fields.zip(stock_values)] 
			end
			[user_stocks, rest]
		end
	end
end