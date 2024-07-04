# frozen_string_literal: true

require "meshtastic"
require "active_record"

require_relative "../app/handlers/application_handler"
require_relative "../app/handlers/directory_handler"
require_relative "../app/handlers/messages_handler"
require_relative "../app/handlers/bulletins_handler"

require_relative "../app/models/application_model"
require_relative "../app/models/message"
require_relative "../app/models/bulletin"

class MeshBBS
  State = Struct.new(:handler, :action, :params)
  User = Struct.new(:nodenum, :short_name) do
    def to_s
      short_name || nodenum
    end
  end

  VALID_HANDLERS = %w(M B D)

  def self.start!(port:)
    new(port:).start!
  end

  def log(output)
    puts "#{} #{output}"
  end

  def initialize(port:)
    @port = port
    @params = {}
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

    if params[:last_request_at] && params[:last_request_at] < Time.now - 300
      params.clear
    end

    params[:last_request_at] = Time.now

    command = packet.decoded.payload.strip.upcase

    if params[:handler].nil? && VALID_HANDLERS.include?(command)
      params[:handler] = command
    end

    if command == "E"
      params.clear
    end

    handler = current_handler(params[:handler])

    unless handler
      messages = Message.where(to: current_user.nodenum, read: false)

      @device.send_message(<<~TEXT.strip, destination: current_user.nodenum)
      Hi #{current_user}!

      You have #{messages.count} unread message#{"s" unless messages.one?}

      Please select an option:
      - [M]ail
      - [B]ulletin Board
      - [D]irectory
      - [H]elp
      TEXT

      return
    end

    if params[:action].nil? && handler::VALID_ACTIONS.include?(command)
      params[:action] = command
      params[:current_step] = 0
    end

    puts "user: #{current_user}, command: #{command}, handler: #{params[:handler]}, action: #{params[:action]}"

    handler.new(
      device: @device,
      current_user: current_user,
      params: params,
      packet: packet
    ).handle_packet
  end

  def current_handler(handler)
    case handler
    when "M"
      MessagesHandler
    when "B"
      BulletinsHandler
    when "D"
      DirectoryHandler
    end
  end
end
