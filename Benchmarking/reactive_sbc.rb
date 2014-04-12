#!/usr/bin/env ruby
# encoding: UTF-8

require 'eventmachine'

require_relative '../lib/protocol.rb'
require_relative '../lib/message_helper.rb'

class TestAgent < EM::Connection
  include Requests   
  include MessagingHelperEM


  def initialize(user_id, password, max_requests)
    super
    @max_requests = max_requests
    @sent = 0
    @active = false
    @user_id = user_id
    @password = password
    @money = 0
    @log.level = Logger::DEBUG
  end

  def connection_completed
    @active = true
  end

  def receive_data data
    responses = gather_responses data
    process_responses responses

    close_connection if @sent >= @max_requests
    #puts "I (user#{@user_id}) received some data...after #{(Time.now - @timestamp ) * 1000} ms."
    stock_id, amount, price = 2,1,1
    if @stocks.include? stock_id and rand(2).even?
      queue_request :sell_stock, {:stock_id => stock_id, :amount => amount, :price => price}
    elsif @money > 0
      queue_request :buy_stock, {:stock_id => stock_id, :amount => amount, :price => price}
      @money -= amount * price
    elsif not @orders.empty?
        order_id = @orders.first[:order_id]
        queue_request :cancel_order, {:order_id => order_id}
  
        @orders.delete(order_id)
    else
      queue_request :get_my_stocks 
    end    
    @timestamp = Time.now
    @sent += 1
  end

  def post_init
    #10.times { queue_request :register_me, {:password => @password} } 

    @log.info "User(#{@user_id}) with password(#{@password})"
    queue_request :login_me, {:user_id => @user_id, :password => @password}

    queue_request :get_my_orders
    queue_request :get_my_stocks

    @timestamp = Time.now
  end

  def unbind
    p 'Connection closed'
    @active = false
  end

  def active?
    @active
  end

  def on_order_change(data)
    super

    unless @orders.include? data[:order_id]
      # Notification order have been distrubed, so server must pay the penalty... 
      queue_request :get_my_orders
      queue_request :get_my_stocks
    end
  end
end

EventMachine.threadpool_size = 10
# On systems without epoll its a no-op.
EventMachine.epoll

simulation_timestamp = Time.now
agents_count = 500
request_count = 100
connections = []

EventMachine.run do
	Signal.trap("INT")   { EventMachine.stop }
	Signal.trap("TERM")  { EventMachine.stop }
  EventMachine.add_shutdown_hook { puts "Closing simulation."}
  agents_count.times do |i|
    connections << EventMachine::connect('192.168.0.3', 12345, TestAgent, i + 2, "ąąąąą", request_count)
	end
  
  EventMachine.add_periodic_timer 0.1 do 
    EventMachine.stop unless connections.any?(&:active?)
    puts "Active connections: #{connections.count(&:active?)}."
  end
end

timespan = Time.now - simulation_timestamp
# login + get_my_stocks + get_my_orders and sending buy or sell.
request_count = request_count + 3
puts "Simulation with #{agents_count} agents (each sent #{request_count} messages) finished after #{timespan} sec."
puts "Requests sent overall: #{agents_count * request_count}."
puts "RPS: #{agents_count * request_count / timespan}." 

