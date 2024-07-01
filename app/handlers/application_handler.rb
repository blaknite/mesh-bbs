# frozen_string_literal: true

class ApplicationHandler
  attr_reader :current_user, :device, :params, :packet

  def initialize(current_user:, device:, params:, packet:)
    @current_user = current_user
    @device = device
    @params = params
    @packet = packet
  end
end
