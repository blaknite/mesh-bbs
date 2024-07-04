# frozen_string_literal: true

class MessagesHandler < ApplicationHandler
  VALID_ACTIONS = %w(R S)

  def handle_packet
    case params[:action]
    when "R"
      handle_read
    when "S"
      handle_send
    else
      handle_menu
    end
  end

  def handle_menu
    messages = Message.where(to: current_user.nodenum, read: false)

    device.send_message(<<~TEXT.strip, destination: current_user.nodenum)
      You have #{messages.count} unread message#{"s" unless messages.one?}

      Please select an option:
      - [R]ead mail
      - [S]end mail
      - [E]xit
    TEXT
  end

  def handle_read
    messages = Message.where(to: current_user.nodenum, read: false).order(created_at: :asc)
    message = messages.first

    if message
      case params[:current_step]
      when 0
        from_short_name = device.nodes[message.from.to_i]&.user&.short_name
        header = <<~TEXT.strip
          From: #{from_short_name || message.from}
          Subject: #{message.subject}
          Posted: #{message.created_at.in_time_zone("Adelaide").strftime("%Y-%m-%d %H:%M")}
        TEXT
        bytesize = (message.body.bytesize + header.bytesize)

        if bytesize <= 228
          device.send_message("#{header}\n\n#{message.body}", destination: current_user.nodenum)
        else
          device.send_message(header, destination: current_user.nodenum)
          device.send_message(message.body, destination: current_user.nodenum)
        end

        message.update!(read: true)

        if messages.many?
          device.send_message("Read next message? Y/N:", destination: current_user.nodenum)
          params[:current_step] += 1

          return
        end
      when 1
        if packet.decoded.payload.strip[0].upcase == "Y"
          handle_read
          return
        end
      else
        device.send_message("No more messages", destination: current_user.nodenum)
      end
    else
      device.send_message("No new mail", destination: current_user.nodenum)
    end

    params[:current_step] = 0
    params[:action] = nil

    handle_menu
  end

  def handle_send
    case params[:current_step]
    when 0
      device.send_message("Enter node short name:", destination: current_user.nodenum)
      params[:current_step] += 1
    when 1
      short_name = packet.decoded.payload.strip.upcase
      to_node = device.nodes.values.detect { |node| node.user.short_name.upcase == short_name }

      unless to_node
        device.send_message("Node not in database", destination: current_user.nodenum)

        params[:current_step] = 0
        params[:action] = nil

        handle_menu

        return
      end

      device.send_message("Enter subject:", destination: current_user.nodenum)

      params[:to_node] = to_node
      params[:current_step] += 1
    when 2
      device.send_message("Enter message:", destination: current_user.nodenum)

      params[:subject] = packet.decoded.payload
      params[:current_step] += 1
    when 3
      Message.create!(
        to: params[:to_node].num,
        from: current_user[:nodenum],
        subject: params[:subject].encode("UTF-8", "UTF-8"),
        body: packet.decoded.payload.encode("UTF-8", "UTF-8")
      )

      device.send_message("Message saved", destination: current_user.nodenum)
      device.send_message(
        "You have a new message from #{current_user}.\n\nReply [H] for options:",
        destination: params[:to_node].num
      )

      params[:to_node] = nil
      params[:subject] = nil
      params[:current_step] = 0
      params[:action] = nil

      handle_menu
    end
  end
end
