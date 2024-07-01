# frozen_string_literal: true

class DirectoryHandler < ApplicationHandler
  def handle_packet
    case params[:action]
    when "L"
      device.nodes.values.each_slice(25) do |nodes|
        device.send_message(nodes.map { |node| node.user.short_name }.join(", "), destination: current_user.nodenum)
      end

      sleep 0.1
    end

    device.send_message(<<~TEXT.strip, destination: current_user.nodenum)
      There are #{device.nodes.values.length} nodes in the directory

      Please select an option:
      - [L]ist nodes
      - [E]xit
    TEXT
  end
end
