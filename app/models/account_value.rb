class AccountValue < ApplicationRecord
  belongs_to :account

  # amount can be negative — a liability (mortgage) snapshot is a balance owed.
  validates :recorded_on, presence: true
  validates :amount, presence: true, numericality: true

  # Oldest snapshot first — the natural order for trend lines and % change.
  scope :chronological, -> { order(:recorded_on) }
end
