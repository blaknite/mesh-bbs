# frozen_string_literal: true

class Message < ApplicationModel
  validates :to, presence: true
  validates :from, presence: true
  validates :subject, presence: true
  validates :body, presence: true
end
