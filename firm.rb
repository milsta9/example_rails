# frozen_string_literal: true

class Firm < ApplicationRecord
  MAX_SCHEDULES = 2

  include Discard::Model
  include HasActive
  include HasChecked

  belongs_to :owner, class_name: 'Business', inverse_of: :owned_firm
  has_many :trustees, -> { merge(Trustee.kept) },
           inverse_of: :firm, dependent: :destroy
  has_many :users, through: :trustees
  has_many :flags, -> { merge(Flag.kept) },
           inverse_of: :firm, dependent: :destroy
  has_many :features, through: :flags
  has_many :posts, -> { merge(Post.kept) },
           inverse_of: :firm, dependent: :destroy
  has_many :schedules, -> { merge(Schedule.kept) },
           as: :scheduleable, inverse_of: :scheduleable, dependent: :destroy
  has_many :pins, -> { merge(Pin.kept) },
           inverse_of: :firm, dependent: :destroy
  has_many :offers, through: :posts
  has_many :pin_balances, -> { merge(PinBalance.kept) }, inverse_of: :firm
  has_many :firm_reports, inverse_of: :firm
  has_many :like_dislikes, through: :posts
  has_many :visited_locations, through: :pins
  has_many :reached_users, class_name: 'User', through: :pins, source: :users

  validates :name, :phone_number, :lat, :lng, :status, presence: true
  validates :about, length: { minimum: 1, maximum: 160 }, allow_nil: true
  # validates :website, url: true, allow_blank: true
  validates :business_type, length: { maximum: 40 }
  # validates :schedules, length: { is: MAX_SCHEDULES }

  before_validation :set_default_schedules
  after_validation :geocode, if: :address_changed?
  after_commit :create_dynamic_link

  accepts_nested_attributes_for :schedules, allow_destroy: false
  accepts_nested_attributes_for :flags, allow_destroy: true

  mount_base64_uploader :photo, PhotoUploader

  geocoded_by :address, latitude: :lat, longitude: :lng

  acts_as_taggable

  def address
    [zip, street, city, state].compact.join(', ')
  end

  def geolocated?
    lat.present? && lat != 0 && lng.present? && lng != 0
  end

  def home_pin
    pins.select(&:is_home).first
  end

  def active_pins_count
    Pin.all.where('firm_id = ? and status = ?', id, 0).count
  end

  def reports_count
    Report.where(post_id: posts.ids).count
  end

  def likes_count
    like_dislikes.like.count
  end

  def pins_count
    pins.count
  end

  def reached_users_count
    reached_users.count
  end

  def available_balance
    pin_balances.sum(:amount_in_cents)
  end

  ransacker :status, formatter: proc { |v| statuses[v] } do |parent|
    parent.table[:status]
  end

  def discard_firm
    discard
    trustees.each(&:discard)
    flags.each(&:discard)
    schedules.each(&:discard)
    pin_balances.each(&:discard)
    posts.each(&:discard_post)
    pins.each(&:discard_pin)
  end

  private

  def create_dynamic_link
    CreateDynamicLinkJob.perform_later(class_name: 'Firm', id: id)
  end

  def set_default_schedules
    return if schedules.size >= MAX_SCHEDULES

    time = Time.new.change(hour: 0, min: 0)

    if schedules.empty?
      # if there's no schedule, we add a schedule with all days enabled
      schedules.new(starts: time, ends: time, week_days: [0, 1, 2, 3, 4, 5, 6])
    end

    (MAX_SCHEDULES - schedules.size).times do
      # fill in any remaining schedule
      schedules.new(starts: time, ends: time, week_days: [])
    end
  end

  def address_changed?
    zip_changed? || street_changed? || city_changed? || state_changed?
  end
end
