# frozen_string_literal: true

require "meshtastic"
require "active_record"

require_relative "../app/handlers/application_handler"
require_relative "../app/handlers/directory_handler"
require_relative "../app/handlers/messages_handler"

require_relative "../app/models/application_model"
require_relative "../app/models/message"

class MeshBBS
  State = Struct.new(:handler, :action, :params)
  User = Struct.new(:nodenum, :short_name) do
    def to_s
      short_name || nodenum
    end
  end

  VALID_MODULES = %w(M D)

  def self.start!(port:)
    new(port:).start!
  end

  def log(output)
    puts "#{} #{output}"
  end

  def initialize(port:)
    @port = port
    @params = {}
    @connection = nil
    @device = nil
  end

  def start!
    puts <<~TEXT

      ███╗   ███╗███████╗███████╗██╗  ██╗████████╗ █████╗ ███████╗████████╗██╗ ██████╗    ██████╗ ██████╗ ███████╗
      ████╗ ████║██╔════╝██╔════╝██║  ██║╚══██╔══╝██╔══██╗██╔════╝╚══██╔══╝██║██╔════╝    ██╔══██╗██╔══██╗██╔════╝
      ██╔████╔██║█████╗  ███████╗███████║   ██║   ███████║███████╗   ██║   ██║██║         ██████╔╝██████╔╝███████╗
      ██║╚██╔╝██║██╔══╝  ╚════██║██╔══██║   ██║   ██╔══██║╚════██║   ██║   ██║██║         ██╔══██╗██╔══██╗╚════██║
      ██║ ╚═╝ ██║███████╗███████║██║  ██║   ██║   ██║  ██║███████║   ██║   ██║╚██████╗    ██████╔╝██████╔╝███████║
      ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝ ╚═════╝    ╚═════╝ ╚═════╝ ╚══════╝

    TEXT

    puts "Connecting to Meshtastic node..."
    @device = Meshtastic.connect(:serial, port: @port)
    puts "Connected to node #{@device.node_num}.\n\n"

    @device.on(:packet, lambda { |packet|
      handle_packet(packet)
    })
  end

  private

  def handle_packet(packet)
    return unless packet.payload_variant == :decoded
    return unless packet.decoded.portnum == :TEXT_MESSAGE_APP
    return unless packet.channel == 0 && packet.to == @device.node_num

    current_user = User.new(
      nodenum: packet.from,
      short_name: @device.nodes[packet.from]&.user&.short_name
    )
    params = @params[current_user[:nodenum]] ||= {}

    motd = "Welcome to the Meshtastic BBS."

    command = packet.decoded.payload.strip[0].upcase
    if params[:handler].nil? && VALID_MODULES.include?(command)
      params[:handler] = command
      params[:action] = nil
      params[:current_step] = 0
    elsif params[:handler] && params[:action].nil?
      params[:action] = command
    end

    puts "user: #{current_user}, command: #{command}, handler: #{params[:handler]}, action: #{params[:action]}"

    if command == "E"
      params.clear
    end

    case params[:handler]
    when "M"
      MessagesHandler.new(
        device: @device,
        current_user: current_user,
        params: params,
        packet: packet
      ).handle_packet
    when "D"
      DirectoryHandler.new(
        device: @device,
        current_user: current_user,
        params: params,
        packet: packet
      ).handle_packet
    else
      messages = Message.where(to: current_user.nodenum, read: false)

      @device.send_message(<<~TEXT.strip, destination: current_user.nodenum)
        Hi #{current_user}!

        #{motd}

        You have #{messages.count} unread message#{"s" unless messages.one?}

        Please select an option:
        - [M]ail
        - [D]irectory
        - [H]elp
      TEXT
    end
  end
end
