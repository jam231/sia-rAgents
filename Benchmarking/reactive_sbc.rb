#!/usr/bin/env ruby
# encoding: UTF-8

require 'eventmachine'

require_relative '../lib/protocol.rb'

class TestAgent < EM::Connection
  include Requests  
  include Responses
  def initialize(user_id, password, max_requests)
    @max_requests = max_requests
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
  
    #puts "I (user#{@user_id}) received some data...after #{(Time.now - @timestamp ) * 1000} ms."
    if (@user_id + @received).even?
      send_data sell_stock 2,1,1
    else
      send_data sell_stock 2,1,1
    end

    @timestamp = Time.now
    close_connection if @received >= @max_requests
  end

  def post_init
    #10.times { send_data register_me @password }
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
          puts "user#{@user_id} - order #{payload[:order_id]} completed."
        when :order_accepted
          #puts "user#{@user_id} - order accepted: #{payload[:order_id]}"
        when :order_change
          puts "user#{@user_id} - order #{payload[:order_id]} changed."
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
          #puts "fail with #{payload}"
        when :ok 
          puts "user#{@user_id} -  ok"
        else
          puts "user#{@user_id} - something else #{name} - #{payload}"     
        end
      end
    end
end

EventMachine.threadpool_size = 6
# On systems without epoll its a no-op.
EventMachine.epoll

simulation_timestamp = Time.now
agents_count = 100
request_count = 10
connections = []

EventMachine.run do
	Signal.trap("INT")   { EventMachine.stop }
	Signal.trap("TERM")  { EventMachine.stop }
  EventMachine.add_shutdown_hook { puts "Closing simulation."}
  agents_count.times do |i|
    connections << EventMachine::connect('192.168.0.6', 12345, TestAgent, i + 10, "ąąąąą", request_count)
	end
  
  EventMachine.add_periodic_timer 1 do 
    EventMachine.stop unless connections.any?(&:active?)
    puts "Active connections: #{connections.count(&:active?)}."
  end
end

timespan = Time.now - simulation_timestamp
# login + get_my_stocks and sending buy or sell.
request_count = request_count + 2
puts "Simulation with #{agents_count} agents (each sent #{request_count} messages) finished after #{timespan} sec."
puts "Requests sent overall: #{agents_count * request_count}."
puts "RPS: #{agents_count * request_count / timespan}." 

