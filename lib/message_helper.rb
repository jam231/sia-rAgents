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
require 'time'

module MessagingHelper
    include Responses

  def initialize(*args, &block)
    @message_queue = Utils::Queue.new 

    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO

    @subscribed_stocks = Set.new
    @stocks = {}
    @orders = {}
    @stock_info = {}

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

    request_name, order = @message_queue.shift
    order_id = data[:order_id]
    
    if @orders.include? order_id
      @log.warn "user(#{@user_id}) - order #{order_id} have already been included."
    else
      case request_name
      when :sell_stock
        stock_id = order[:stock_id]
        @orders.merge! order_id => (order.merge! :order_type => :sell_order)
        # Market substracts (secures) from you available stocks the amount you want to sell 
        @stocks[stock_id] -= order[:amount]
        @stocks.delete(stock_id) unless @stocks[stock_id] > 0
      when :buy_stock
        @orders.merge! order_id => (order.merge! :order_type => :buy_order)
        # Market substracts (secures) money needed for the purchase.
        @money -= order[:amount] * order[:price]
        @orders.merge! order_id => order
      end
    end

    @log.info "user(#{@user_id}) - order(#{order}) accepted. order_id(#{order_id})"
  end

  def on_order_change(data)
    order_id = data[:order_id]
    amount_difference = data[:amount]
    price = data[:price] 
    stock_id = data[:stock_id]
    
    @log.info "user(#{@user_id}) - order(#{order_id}) has changed."
    
    if @orders.include? order_id
      order_changed = @orders[order_id] 
      order_changed[:amount] -= amount_difference
      
      case order_changed[:order_type]
      when :sell_order
        @money ||= 0
        @money += data[:price] * amount_difference  
      when :buy_order
        @stocks[stock_id] ||= 0
        @stocks[stock_id] += amount_difference
      else
        @log.warn "user(#{@user_id}) - unrecognized order type(#{order_changed[:order_type]})."
      end
    else 
      @log.warn "user(#{@user_id}) - order(#{order_id}) not on the list!."
    end
  end

  def on_order_completed(data)
    order_id = data[:order_id]
    @orders.delete(order_id)
    
    @log.info "user(#{@user_id}) - order(#{order_id}) has completed."
    @log.debug "user(#{@user_id}) - remaining orders count = #{@orders.size}."
  end

  def on_list_of_stocks(data) 
    @log.fatal "user(#{@user_id}) - message queue is empty!." if @message_queue.empty?
                     
    @message_queue.shift
    @stocks.clear

    data[:stocks].each do |stock|
      stock_id, amount = stock[:stock_id], stock[:amount] 
      if stock_id == 1
    	 @money = amount
      else
			 @stocks.merge! stock_id => amount
		  end
    end
    
    @log.debug "user(#{@user_id}) - owned stocks(#{@stocks.size}) = #{@stocks}."
    @log.debug "user(#{@user_id}) - money = #{@money}."
  end

  def on_list_of_orders(data)
    @log.fatal "user(#{@user_id}) - message queue is empty!." if @message_queue.empty?

    @message_queue.shift
    @orders.clear
    
    data[:orders].each do |order|
      @orders.merge! order[:order_id] => order.tap { |hash| hash.delete(:order_id) }
    end

    @log.debug "user(#{@user_id}) - pending orders(#{@orders.size}) = #{@orders}."
  end
  
  def on_stock_info(data)
    @log.fatal "user(#{@user_id}) - message queue is empty!." if @message_queue.empty?

    message =   @message_queue.shift

    stock_id = data[:stock_id]

    @stock_info.merge! stock_id => data.tap { |hash| hash.delete(:stock_id) }
                                       .merge!(:timestamp => Time.now.utc.iso8601) 
    @log.debug "user(#{@user_id}) - New stock_info(#{@stock_info[stock_id]}) data for stock(#{stock_id})."
  end

  def on_fail(data)
    @log.fatal "user(#{@user_id}) - message queue is empty!." if @message_queue.empty?

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

      @log.debug "user(#{@user_id}) - order(#{order_id}) successfully canceled."
    when :login_me
      user_id         = message_body[:user_id]

      @log.debug "user(#{@user_id}) - successfully logged."
    when :subscribe
      stock_id        = message_body[:stock_id]

      if @subscribed_stocks.include? stock_id
        @log.debug "user(#{@user_id}) - stock_id(#{stock_id}) already included in subscribed_stocks set." 
      else
        @subscribed_stocks << stock_id
        @log.debug "user(#{@user_id}) - successfully subscribed for stock(#{stock_id})"
      end
    when :unsubscribe
      stock_id        = message_body[:stock_id] 
      unless @subscribed_stocks.include? stock_id
        @log.warn "user(#{@user_id}) - stock_id(#{stock_id}) not included in subscribed_stocks set."
      else
        @subscribed_stocks.delete stock_id
        @log.debug "user(#{@user_id}) - successfully unsubscribed from stock(#{stock_id})"      
      end
    else
      @log.warn "user(#{@user_id}) - confirmation for unrecognized #{message_name} request."
    end   
  end

  def on_register_successful(data)
    @log.fatal "user(#{@user_id}) - message queue is empty!." if @message_queue.empty?

    @message_queue.shift
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
