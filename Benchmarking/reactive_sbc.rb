#!/usr/bin/env ruby
# encoding: UTF-8

require 'eventmachine'

require_relative '../lib/protocol.rb'
require_relative '../lib/message_helper.rb'

class TestAgent < EM::Connection
  include Requests   
  include MessagingHelper

  def initialize(user_id, password, max_requests)
    @max_requests = max_requests
    @received = 0
    @active = false
    @user_id = user_id
    @password = password
    @money = 0
    super 
  end

  def connection_completed
    @active = true
  end

  def receive_data data
    responses = gather_responses data
    @received += responses.size  
    process_responses responses
    
    close_connection if @received >= @max_requests

    #puts "I (user#{@user_id}) received some data...after #{(Time.now - @timestamp ) * 1000} ms."
    stock_id, amount, price = 2,1,1
    if (@user_id + @received).even? and 
      queue_request :sell_stock, {:stock_id => stock_id, :amount => amount, :price => price}
      send_data sell_stock stock_id, amount, price
    elsif @money > 0
      queue_request :buy_stock, {:stock_id => stock_id, :amount => amount, :price => price}
      money -= amount * price
      send_data buy_stock stock_id, amount, price
      close_connection
    else
      puts "user({@user_id) - no money and no stock(#{stock_id})."
      get_my_stocks
    end
    unless @orders.empty?
        order_id = @orders.first.first
        queue_request :cancel_order, {:order_id => order_id}
  
        @orders.delete(order_id)
  
        send_data cancel_order(order_id)
    end
    @timestamp = Time.now
  end

  def post_init
    # 10.times do 
    #   queue_request :register_me, {:password => @password}
    #   send_data register_me @password
    # end
    puts "User(#{@user_id}) with password(#{@password})"
    queue_request :login_me, {:user_id => @user_id, :password => @password}
    send_data login_me(@user_id, @password)

    send_data get_my_stocks
    send_data get_my_orders

    @timestamp = Time.now
  end

  def unbind
    p 'Connection closed'
    @active = false
  end

  def active?
    @active
  end


  private

    def gather_responses(data)
      responses = []
      loop do 
        response, data = from_data data
        break if [:not_enough_bytes, :response_dropped].include? response 
        responses << response
      end
      responses
    end
end

EventMachine.threadpool_size = 10
# On systems without epoll its a no-op.
EventMachine.epoll

simulation_timestamp = Time.now
agents_count = 20
request_count = 100
connections = []

EventMachine.run do
	Signal.trap("INT")   { EventMachine.stop }
	Signal.trap("TERM")  { EventMachine.stop }
  EventMachine.add_shutdown_hook { puts "Closing simulation."}
  agents_count.times do |i|
    connections << EventMachine::connect('192.168.0.7', 12345, TestAgent, i + 10, "ąąąąą", request_count)
	end
  
  EventMachine.add_periodic_timer 1 do 
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

