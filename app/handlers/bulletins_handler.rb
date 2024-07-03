# frozen_string_literal: true

class BulletinsHandler < ApplicationHandler
  def handle_packet
    case params[:action]
    when "R"
      handle_read
    when "P"
      handle_post
    else
      handle_menu
    end
  end

  def handle_menu
    device.send_message(<<~TEXT.strip, destination: current_user.nodenum)
      Please select an option:
      - [R]ead bulletins
      - [P]ost bulletin
      - [E]xit
    TEXT
  end

  def handle_read
    bulletins = Bulletin.order(created_at: :desc)
    bulletin = bulletins.first

    if bulletin
      case params[:current_step]
      when 0
        from_short_name = device.nodes[bulletin.from.to_i]&.user&.short_name
        header = <<~TEXT.strip
          From: #{from_short_name || bulletin.from}
          Subject: #{bulletin.subject}
          Posted: #{bulletin.created_at.in_time_zone("Adelaide").strftime("%Y-%m-%d %H:%M")}
        TEXT
        bytesize = (bulletin.body.bytesize + header.bytesize)

        if bytesize <= 228
          device.send_message("#{header}\n\n#{bulletin.body}", destination: current_user.nodenum)
        else
          device.send_message(header, destination: current_user.nodenum)
          device.send_message(bulletin.body, destination: current_user.nodenum)
        end

        if bulletins.many?
          device.send_message("Read next bulletin? Y/N:", destination: current_user.nodenum)
          params[:current_step] += 1

          return
        else
          device.send_message("No more bulletins", destination: current_user.nodenum)
        end
      when 1
        if packet.decoded.payload.strip[0].upcase == "Y"
          handle_read
          return
        end
      end
    else
      device.send_message("No bulletins", destination: current_user.nodenum)
    end

    params[:current_step] = 0
    params[:action] = nil

    handle_menu
  end

  def handle_post
    case params[:current_step]
    when 0
      device.send_message("Enter subject:", destination: current_user.nodenum)

      params[:current_step] += 1
    when 1
      device.send_message("Enter message:", destination: current_user.nodenum)

      params[:subject] = packet.decoded.payload
      params[:current_step] += 1
    when 2
      Bulletin.create!(
        from: current_user[:nodenum],
        subject: params[:subject].encode("UTF-8", "UTF-8"),
        body: packet.decoded.payload.encode("UTF-8", "UTF-8")
      )

      device.send_message("Bulletin saved", destination: current_user.nodenum)

      params[:current_step] = 0
      params[:action] = nil

      handle_menu
    end
  end
end
