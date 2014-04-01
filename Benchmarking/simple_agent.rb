#!/usr/bin/env ruby
# encoding: UTF-8

require 'eventmachine'


def get_my_orders
	[3].pack('n') + [0x1f].pack('c')
end

def get_my_stocks
  [3].pack('n') + [0x1d].pack('c')
end

def register_me(psswd)
	[2 + 1 + 2 + psswd.bytes.to_a.size].pack('n') + [0].pack('c') +  [psswd.bytes.to_a.size].pack('n') + psswd.bytes.to_a.pack('U*')
end

def login_me(userid, psswd)
  [2 + 1 + 4 + 2 + psswd.bytes.to_a.size].pack('n') + [4].pack('c') + 
         [userid].pack('N') + [psswd.bytes.to_a.size].pack('n') + psswd.bytes.to_a.pack('U*')
end

# Sia agent
class TestAgent < EM::Connection
  @@random_generator = Random.new
  @@max_user_id = 3008
  
  def initialize(user_id, password)
    @user_id = user_id
    @password = password
  end

  def receive_data data
    puts "I (id = #{@user_id}) got some sweet data... #{data.inspect} ...after #{(Time.now - @timestamp ) * 1000} ms."
    #100.times {
    #send_data get_my_orders(12)
  	# send_data register_me("abecadlo")
    #}
    send_data get_my_orders
    @timestamp = Time.now
    
    @received += 1  
    close_connection if @received > $MAX_MESSAGES
  end

  def post_init
    @active = true
    @received = 0
  	#send_data register_me('aaaaa')
    #puts "I'm listening !"
  	#send_data get_my_orders(3)
    #send_data get_my_orders(3)
    #send_data register_me("abecadlo")
    #send_data register_me("abecadlo")
    #100.times { send_data login_me(1, "abecadlo") }
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
agents = 5
$MAX_MESSAGES = 1500

connections = []

EventMachine.run do
	Signal.trap("INT")		{ EventMachine.stop }
	Signal.trap("TERM") 	{ EventMachine.stop }
	EventMachine.add_shutdown_hook { puts "Closing simulation."}
  agents.times do |i|
		connections << EventMachine::connect('192.168.0.3', 12345, TestAgent, i + 10, 'aaaaa')
	end
  
  EventMachine.add_periodic_timer 1 do 
    EventMachine.stop unless connections.any?(&:active?)
  end
end

puts "Simulation with #{agents} agents (each sent #{$MAX_MESSAGES}) finished after #{(Time.now - simulation_timestamp)} sec."


