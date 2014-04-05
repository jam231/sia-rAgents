#!/usr/bin/env ruby
# encoding: UTF-8

require 'eventmachine'

require_relative '../lib/serialization.rb'

def get_my_orders
  Serializer.serialize [3, 0x1f], [:uint16, :uint8]
end

def get_my_stocks
  Serializer.serialize [3, 0x1d], [:uint16, :uint8]
end

def register_me(psswd)
  psswd = Serializer.serialize [psswd], [:utf8]
  request_length = 2 + 1 + psswd.bytesize

  partial = Serializer.serialize [request_length, 0x0], [:uint16, :uint8]
  [partial, psswd].join
end

def login_me(userid, psswd)
  psswd = Serializer.serialize [psswd], [:utf8]
  request_length = 2 + 1 + 4 + psswd.bytesize

  partial = Serializer.serialize [request_length, 0x4, userid], [:uint16, :uint8, :uint32]
  [partial, psswd].join
end

# Sia agent
class TestAgent < EM::Connection
  
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
    puts "I (id = #{@user_id}) got some sweet data... #{data.inspect} ...after #{(Time.now - @timestamp ) * 1000} ms."
    send_data get_my_orders

    @timestamp = Time.now
    @received += 1  

    close_connection if @received >= @max_requests
  end

  def post_init
    send_data register_me "ąąąąą"
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


simulation_timestamp = Time.now
agents_count = 3000
request_count = 300

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
  end
end

timespan = Time.now - simulation_timestamp
puts "Simulation with #{agents_count} agents (each sent #{request_count} messages) finished after #{timespan} sec."
puts "Requests sent overall: #{agents_count * request_count}."
puts "RPS: #{agents_count * request_count / timespan}." 

