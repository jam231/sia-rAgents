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
require 'forwardable'

module MessageHelpers
  class RequestHelper
    include Requests

    extend Forwardable

    def_delegator :@request_queue, :shift, :shift_request
    def_delegator :@request_queue, :empty?, :has_empty_request_queue?

    def initialize(hash_args={}, &block)
      @request_queue = Utils::Queue.new
    end

    # name=symbol, body={field_name=symbol => value}
    def queue_request(name, body = nil)
      @request_queue << [name, body]
    end
  end

  class ResponseHelper
    include Responses

    # optional: hash_args = {logger: ...}
    def initialize(hash_args={}, &block)
      @buffer = ''
      @log = Utils::logger_or_default hash_args[:logger]
      yield if block_given?
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
          @log.debug 'Dropped message...'
        else
          responses << response
        end
      end
      responses
    end
  end


  module MessagingHelper
    extend Forwardable

    def_delegator :@request_helper,  :queue_request, :queue_request
    def_delegator :@response_helper, :gather_responses, :gather_responses

    # optional: hash_args = {logger: ..., response_helper: ...,
    #                        request_helper: ...}
    def initialize(hash_args={}, &block)
      @log             = Utils::logger_or_default hash_args[:logger]
      @response_helper = hash_args[:response_helper] || ResponseHelper.new(hash_args)
      @request_helper  = hash_args[:request_helper]  || RequestHelper.new(hash_args)

      @subscribed_stocks = Set.new
      @stocks            = {}
      @orders            = {}
      @stock_info        = {}

      yield if block_given?
    end

    # responses=[name=symbol, body={field_name=symbol => value}]
    def process_responses(responses)
      responses.each do |name, payload|
        response_handler = "on_#{name}".intern
        if respond_to? response_handler
          send response_handler, payload
        else
          on_default_message payload
        end
      end
    end


    def on_order_accepted(data)
      @log.fatal "user(#{@user_id}) - message queue is empty!." if @request_helper.has_empty_request_queue?

      request_name, order = @request_helper.shift_request
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
      @log.fatal "user(#{@user_id}) - message queue is empty!." if @request_helper.has_empty_request_queue?

      @request_helper.shift_request
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
      @log.fatal "user(#{@user_id}) - message queue is empty!." if @request_helper.has_empty_request_queue?

      @request_helper.shift_request
      @orders.clear

      data[:orders].each do |order|
        @orders.merge! order[:order_id] => order.tap { |hash| hash.delete(:order_id) }
      end

      @log.debug "user(#{@user_id}) - pending orders(#{@orders.size}) = #{@orders}."
    end

    def on_stock_info(data)
      @log.fatal "user(#{@user_id}) - message queue is empty!." if @request_helper.has_empty_request_queue?

      @request_helper.shift_request

      stock_id = data[:stock_id]
      timestamp = { :timestamp => Time.now.utc.iso8601 }
      stock_info = data.tap { |hash| hash.delete(:stock_id) }.merge!(timestamp)

      @stock_info.merge! stock_id => stock_info
      @log.debug "user(#{@user_id}) - New stock_info(#{@stock_info[stock_id]}) data for stock(#{stock_id})."
    end

    def on_fail(data)
      @log.fatal "user(#{@user_id}) - message queue is empty!." if @request_helper.has_empty_request_queue?

      message = @request_helper.shift_request
      @log.debug "user(#{@user_id}) - message #{message} have failed with #{data}."
    end

    def on_ok(data)
      @log.fatal "user(#{@user_id}) - message queue is empty!." if @request_helper.has_empty_request_queue?

      request_name, request_body = @request_helper.shift_request
      on_ok_handler = "on_ok_#{request_name}".intern

      if respond_to? on_ok_handler
        send on_ok_handler, data, request_body
      else
        @log.warn "user(#{@user_id}) - confirmation for unrecognized #{request_name} request."
      end
    end

    def on_ok_subscribe(data, request_body)
      stock_id        = request_body[:stock_id]

      if @subscribed_stocks.include? stock_id
        @log.debug "user(#{@user_id}) - stock_id(#{stock_id}) already included in subscribed_stocks set."
      else
        @subscribed_stocks << stock_id
        @log.debug "user(#{@user_id}) - successfully subscribed for stock(#{stock_id})"
      end
    end

    def on_ok_unsubscribe(data, request_body)
      stock_id        = request_body[:stock_id]
      if @subscribed_stocks.include? stock_id
        @subscribed_stocks.delete stock_id
        @log.debug "user(#{@user_id}) - successfully unsubscribed from stock(#{stock_id})"
      else
        @log.warn "user(#{@user_id}) - stock_id(#{stock_id}) not included in subscribed_stocks set."
      end
    end

    def on_ok_login_me(data, request_body)
      user_id         = request_body[:user_id]

      @log.debug "user(#{@user_id}) - successfully logged."
    end

    def on_ok_cancel_order(data, request_body)
      order_id        = request_body[:order_id]
      canceled_order  = @orders[order_id]

      case canceled_order[:order_type]
      when :buy
        # If canceled order was buy order then return frozen money
        @money += canceled_order[:amount] * canceled_order[:price]
      when :sell
        # If canceled order was sell order then return frozen stocks
        @stocks[canceled_order[:stock_id]] += canceled_order[:amount]
      else
        @log.warning "user(#{@user_id}) - order(#{order_id}) has unrecognized type."
      end
      @orders.delete(order_id)

      @log.debug "user(#{@user_id}) - order(#{order_id}) successfully canceled."
    end

    def on_register_successful(data)
      @log.fatal "user(#{@user_id}) - message queue is empty!." if @request_helper.has_empty_request_queue?

      @request_helper.shift_request
      @log.info "Registered user(#{data[:user_id]})."
    end

    def on_default_message(data)
      @log.warn "user(#{@user_id}) - something else #{name} - #{payload}"
    end
  end


  module MessagingHelperEM
    include MessagingHelper

    # name=symbol, body={field_name=symbol => value}
    def queue_request(name, body = nil)
      super
      # From Ruby docs about Hash:
      # 'Hashes enumerate their values in the order that the
      #  corresponding keys were inserted.'
      if body.nil?
        send_data send(name)
      else
        send_data send(name, *body.values)
      end
    end
  end
end
