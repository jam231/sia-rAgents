#!/usr/bin/env ruby
# encoding: UTF-8

#
# This module helps handling responses from the server via on_* methods.
# It updates stocks and order hashes, 
#
# Queue request with requests for which server returns ok/fail response.  
#   
#
#

require_relative 'protocol.rb'
require_relative 'utils.rb'

require 'logger'
require 'set'

module MessagingHelper
    include Responses

  def initialize(*args, &block)
    @message_queue = Utils::Queue.new 

    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO

    @subscribed_stocks = Set.new
    @stocks = {}
    @orders = {}

    yield if block_given?
  end

  # name=symbol, body={field_name=symbol => value}
  def queue_request(name, body=nil)
    @message_queue << [name, body].compact;
  end

  # responses=[name=symbol, body={field_name=symbol => value}]
  def process_responses(responses)
    responses.each do |name, payload|
      case name
      when :order_accepted
        on_order_accepted payload
      when :order_completed
        on_order_completed payload
      when :order_change
        on_order_change payload
      when :stock_info
        on_stock_info payload
      when :list_of_stocks
        on_list_of_stocks payload
      when :list_of_orders
        on_list_of_orders payload
      when :fail
        on_fail payload
      when :ok 
        on_ok payload
      when :register_successful
        on_register_successful payload
      else
        on_default_message payload
      end
    end
  end

  def on_order_accepted(data)
    @log.fatal "user(#{@user_id}) - message queue is empty!." if @message_queue.empty?
    message = @message_queue.shift
    order_id = data[:order_id]
    if @orders.include? order_id
      @log.warn "user(#{@user_id}) - order #{order_id} have already been included."
    else
      order_body = message[1]
      @orders.merge! order_id => order_body
    end
    @log.info "user(#{@user_id}) - order(#{message}) accepted. order_id(#{data[:order_id]})"
  end

  def on_order_change(data)
    order_id = data[:order_id]
    amount_difference = data[:amount]
    price = data[:price] 
    stock_id = data[:stock_id]
    @log.info "user(#{@user_id}) - order(#{order_id}) has changed."
    if @orders.include? order_id 
      @orders[order_id][:amount] -= amount_difference
      @money ||= 0
      @money += data[:price] * amount_difference if @orders[order_id][:order_type] == 2 #SELL 
      @stocks[stock_id] ||= 0
      @stocks[stock_id] += amount_difference if @orders[order_id][:order_type] == 1 # BUY 
    else 
      @log.warn "user(#{@user_id}) - order not on the list!."
    end
  end

  def on_order_completed(data)
    order_id = data[:order_id]
    @orders.delete(order_id)
    @log.info "user(#{@user_id}) - order(#{order_id}) has completed."
    @log.debug "user(#{@user_id}) - remaining orders count = #{@orders.size}."
  end

  def on_list_of_stocks(data)                      
    @message_queue.shift
    @stocks.clear
    data[:stocks].each do |stock|
      if stock[:stock_id] == 1
    	 	@money = stock[:amount]
      else
			 @stocks[stock[:stock_id]] = stock.delete_if { |key| key == :stock_id }
		  end
    end
    @log.debug "user(#{@user_id}) - owned stocks count = #{@stocks.size}."
    @log.debug "user(#{@user_id}) - money = #{@money}."
  end

  def on_list_of_orders(data)
    @message_queue.shift
    @orders.clear
    data[:orders].each do |order|
      @orders[order[:order_id]] = order.delete_if { |key| key == :order_id }
    end

    @log.debug "user(#{@user_id}) - orders size = #{@orders.size}."
  end
  
  def on_stock_info(data)
    message = @message_queue.shift

    @log.debug "user(#{@user_id}) - message (#{message}) => data received(#{data})."
  end

  def on_fail(data)
    message = @message_queue.shift
    @log.debug "user(#{@user_id}) - message #{message} have failed with #{data}."
  end

  def on_ok(data)
    @log.fatal "user(#{@user_id}) - message queue is empty!." if @message_queue.empty?
    message_name, message_body = @message_queue.shift
    
    ## FIXME: Clean it

    case message_name
    when :cancel_order 
      order_id        = message_body[:order_id]
      canceled_order  = @orders[order_id]
      # If canceled order was buy order then return frozen money
      @money += canceled_order[:amount] * canceled_order[:price] if canceled_order[:order_type] == 1
      # If canceled order was sell order then return frozen stocks
      @stocks[canceled_order[:stock_id]] += canceled_order[:amount] if canceled_order[:order_type] == 2
      @orders.delete(order_id)
    when :sell_order
      @orders.merge! data[:order_id] => (message_body.merge! :order_type => 2)
      # Market substracts (secures) from you available stocks the amount you want to sell 
      @stocks[message_body[:stock_id]] -= message_body[:amount]
      @stocks.delete(message_body[:stock_id]) unless @stocks[message_body[:stock_id]] > 0
    when :buy_order
      @orders.merge! data[:order_id] => (message_body.merge! :order_type => 1)
      # Market substracts (secures) money needed for the purchase.
      @money -= message_body[:amount] * message_body[:price]
    else
      @log.warn "user(#{@user_id}) - confirmation for unrecognized requestt #{message_name}."
    end   
    @log.debug "user(#{@user_id}) -  confirmation for request #{message_name}."
  end

  def on_register_successful(data)
    message_body = @message_queue.shift[1]
    @log.info "Registered user(#{data[:user_id]})." 
  end

  def on_default_message(data)
    @log.warn "user(#{@user_id}) - something else #{name} - #{payload}"     
  end
end


module MessagingHelperEM
  include MessagingHelper


  def initialize(*args, &block)
    super
    @buffer = ""
    yield if block_given?
  end 


  def queue_request(name, args=nil)
    super
    # From Ruby docs about Hash:
    # 'Hashes enumerate their values in the order that the corresponding keys were inserted.'
    unless args.nil?
      send_data send(name, *args.values)
    else 
      send_data send(name)
    end
  end

  def gather_responses(data)
    data = [@buffer, data].join
    responses = []
    loop do 
      response, data = from_data data
      if response == :not_enough_bytes 
        @buffer = data
        break
      elsif response == :response_dropped
        @log.debug "Dropped message..."
      else
        responses << response
      end
    end
    responses
  end
end
