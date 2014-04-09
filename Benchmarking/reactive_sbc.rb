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
    @buffer = ""
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
    if @stocks.include? stock_id and rand(2).even?
      queue_request :sell_stock, {:stock_id => stock_id, :amount => amount, :price => price}
    elsif @money > 0
      queue_request :buy_stock, {:stock_id => stock_id, :amount => amount, :price => price}
      @money -= amount * price
      close_connection
    elsif not @orders.empty?
        order_id = @orders.first.first
        queue_request :cancel_order, {:order_id => order_id}
  
        @orders.delete(order_id)
    else
      get_my_stocks
    end
    
    @timestamp = Time.now
  end

  def post_init
    #10.times { queue_request :register_me, {:password => @password} } 

    puts "User(#{@user_id}) with password(#{@password})"
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

  private

    def gather_responses(data)
      data = [@buffer, data].join
      responses = []
      loop do 
        response, data = from_data data
        if :not_enough_bytes == response 
          @buffer = data
          break
        end
        responses << response unless response == :response_dropped
      end
      responses
    end
end

EventMachine.threadpool_size = 1
# On systems without epoll its a no-op.
EventMachine.epoll

simulation_timestamp = Time.now
agents_count = 10
request_count = 20
connections = []

EventMachine.run do
	Signal.trap("INT")   { EventMachine.stop }
	Signal.trap("TERM")  { EventMachine.stop }
  EventMachine.add_shutdown_hook { puts "Closing simulation."}
  agents_count.times do |i|
    connections << EventMachine::connect('localhost', 12345, TestAgent, i + 2, "ąąąąą", request_count)
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

