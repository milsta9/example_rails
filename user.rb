# frozen_string_literal: true

require 'csv'

class User < ApplicationRecord
  include Discard::Model
  include HasActive
  include HasUpdateLocation

  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :trackable, :confirmable,
         authentication_keys: %i[email]

  include DeviseTokenAuth::Concerns::User

  has_many :support_tickets, -> { merge(SupportTicket.kept) },
           as: :ticketable, dependent: :destroy
  has_many :alerts, -> { merge(Alert.kept) },
           inverse_of: :user, dependent: :destroy
  has_many :notifications, through: :alerts
  has_many :views, -> { merge(View.kept) },
           inverse_of: :user, dependent: :destroy
  has_many :swipes, -> { merge(Swipe.kept) },
           inverse_of: :user, dependent: :destroy
  has_many :visited_locations, -> { merge(VisitedLocation.kept) },
           inverse_of: :user, dependent: :destroy
  has_many :visited_pins, -> { distinct },
           through: :visited_locations, source: :pin
  has_many :like_dislikes, -> { merge(LikeDislike.kept) },
           inverse_of: :user, dependent: :destroy
  has_many :user_posts, through: :like_dislikes, source: :post
  has_many :reports, -> { merge(Report.kept) },
           inverse_of: :user, dependent: :destroy

  validates :username, presence: true, uniqueness: true,
                       format: { with: /\A[a-zA-Z0-9_\.]*\Z/ }
  validates :birthday, presence: true

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP },
                    presence: true, uniqueness: { case_sensitive: false }

  before_save :check_birthday_changed, on: :update

  acts_as_birthday :birthday

  mount_base64_uploader :photo, PhotoUploader

  def self.create_user_from_fb(result)
    where(email: result['email']).first_or_create do |user|
      user.first_name = result['first_name']
      user.last_name = result['last_name']
      # TODO: confirm this is unique.
      user.username = result['name'].delete(' ')
      # TODO: birthday can be blank so we need to make this field can be null.
      user.birthday = result['birthday'] || '2020-01-01'
      user.password = Devise.friendly_token[0, 20]
    end
  end

  # allow to login using either username or email
  def self.dta_find_by(args = {})
    if args[:email].present? && args['provider'] == 'email'
      super(email: args[:email].downcase, 'provider' => 'email') ||
        super(username: args[:email].downcase, 'provider' => 'email')
    else
      super(args)
    end
  end

  def as_json(*)
    super.except('provider', 'uid', 'allow_password_change', 'status',
                 'created_at', 'updated_at', 'discarded_at', 'blocked',
                 'facebook_token', 'google_token').tap do |hash|
      hash['can_change_birthday'] = !user_changed_birthday?
    end
  end

  def name
    "#{first_name} #{last_name}"
  end

  def likes
    like_dislikes.where(is_like: true)
  end

  def liked_posts
    user_posts.where(like_dislikes: { is_like: true })
  end

  def discard_user
    discard
    views.each(&:discard)
    swipes.each(&:discard)
    visited_locations.each(&:discard)
    like_dislikes.each(&:discard)
    reports.each(&:discard)
  end

  def active_for_authentication?
    super && !discarded? && !blocked? && !inactive?
  end

  def inactive_message
    !discarded? ? super : :deleted_account
  end

  def self.to_csv
    attributes = %w[id name email username phone birthday lat lng
                    status blocked created_at updated_at]

    CSV.generate(headers: true) do |csv|
      csv << attributes
      all.each do |user|
        csv << attributes.map { |attr| user.send(attr) }
      end
    end
  end

  private

  def check_birthday_changed
    return unless persisted? && will_save_change_to_birthday?

    assign_attributes(user_changed_birthday: true)
  end
end
