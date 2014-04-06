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
    responses = []
    loop do 
      response, data = from_data data
      break if [:not_enough_bytes, :response_dropped].include? response 
      responses << response
    end 
    puts "I (id = #{@user_id}) got some sweet data... #{responses} ...after #{(Time.now - @timestamp ) * 1000} ms."
    send_data get_my_stocks

    @timestamp = Time.now
    @received += 1  

    close_connection if @received >= @max_requests
  end

  def post_init
    #send_data register_me @password
    puts "User(#{@user_id}) with password(#{@password})"
    send_data login_me(@user_id, @password)
    @timestamp = Time.now
  end

  def unbind
    p 'Connection closed'
    @active = false
  end

  def active?
    @active
  end
end

EventMachine.threadpool_size = 4
# On systems without epoll its a no-op.
EventMachine.epoll

simulation_timestamp = Time.now
agents_count = 5000
request_count = 200

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
puts "Simulation with #{agents_count} agents (each sent #{request_count} messages) finished after #{timespan} sec."
puts "Requests sent overall: #{agents_count * request_count}."
puts "RPS: #{agents_count * request_count / timespan}." 

