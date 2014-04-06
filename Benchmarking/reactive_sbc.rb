#!/usr/bin/env ruby
# encoding: UTF-8

require 'eventmachine'

require_relative '../lib/protocol.rb'

class TestAgent < EM::Connection
  include Requests  
  include Responses
  @min_stock_id, @max_stock_id = 2, 21
  def initialize(user_id, password, max_requests, min_stock_id=2, max_stock_id=21)
    @min_stock_id, @max_stock_id = min_stock_id, max_stock_id
    @max_requests = max_requests * (max_stock_id - min_stock_id) + 2
    @received = 0
    @active = false
    @user_id = user_id
    @password = password
  end

  def connection_completed
    @active = true
  end

  def receive_data data
    responses = gather_responses data
    @received += responses.size  
    process_responses responses
    puts "I (id = #{@user_id}) received some data...after #{(Time.now - @timestamp ) * 1000} ms."

    @timestamp = Time.now
    close_connection if @received >= @max_requests
  end

  def post_init
    #5.times { send_data register_me @password }
    puts "User(#{@user_id}) with password(#{@password})"
    send_data login_me(@user_id, @password)
    send_data get_my_stocks
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
  
    def process_responses(responses)
      responses.each do |name, payload|
        case name
        when :order_completed
          puts "Order #{payload[:order_id]} completed."
        when :order_accepted
          puts "Order accepted: #{payload[:order_id]}"
        when :order_change
          puts "Order #{payload[:order_id]} changed."
        when :list_of_stocks
          @list_of_stocks = payload[:stocks].delete_if do |hsh| 
                                            if hsh[:stock_id] == 1
                                              @money = hsh[:amount]
                                              true
                                            end  
                            end
        when :list_of_orders
          @list_of_orders = payload[:orders]
        when :fail
          puts "fail with #{payload}"
        when :ok 
          puts "ok"
        else
          puts "Something else #{name} - #{payload}"     
        end
        @min_stock_id.upto(@max_stock_id) do |stock_id|
          if (@user_id + stock_id).even?
            send_data buy_stock stock_id, 1, 1
          else
            send_data sell_stock stock_id, 1, 1
          end
        end  
      end
    end
end

EventMachine.threadpool_size = 1
# On systems without epoll its a no-op.
EventMachine.epoll

simulation_timestamp = Time.now
agents_count = 2
request_count = 3
min_stock_id, max_stock_id = 2, 21
connections = []

EventMachine.run do
	Signal.trap("INT")   { EventMachine.stop }
	Signal.trap("TERM")  { EventMachine.stop }
  EventMachine.add_shutdown_hook { puts "Closing simulation."}
  agents_count.times do |i|
    connections << EventMachine::connect('localhost', 12345, TestAgent, i + 10, "ąąąąą", request_count)
	end
  
  EventMachine.add_periodic_timer 1 do 
    EventMachine.stop unless connections.any?(&:active?)
  end
end

timespan = Time.now - simulation_timestamp
# login + get_my_stocks and sending buy or sell stock for every stock_id in range.
request_count = request_count * (max_stock_id - min_stock_id) + 2
puts "Simulation with #{agents_count} agents (each sent #{request_count} messages) finished after #{timespan} sec."
puts "Requests sent overall: #{agents_count * request_count}."
puts "RPS: #{agents_count * request_count / timespan}." 

