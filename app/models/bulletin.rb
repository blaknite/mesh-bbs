# frozen_string_literal: true

class Bulletin < ApplicationModel
  validates :from, presence: true
  validates :subject, presence: true
  validates :body, presence: true
end
