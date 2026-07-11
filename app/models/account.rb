class Account < ApplicationRecord
  # Broad grouping used for colour-coding and, later, allocation/risk views.
  # Registered accounts are the Canadian tax-sheltered ones (TFSA, RRSP, RESP...).
  KINDS = %w[tfsa rrsp resp fhsa non_registered crypto cash liability credit_card].freeze

  has_many :account_values, dependent: :destroy

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }

  # The most recent monthly snapshot, or nil if none recorded yet.
  def latest_value
    account_values.order(recorded_on: :desc).first
  end

  # This account's current worth (from its latest snapshot), or nil.
  def current_amount
    latest_value&.amount
  end

  # Human-friendly label for a kind, e.g. "non_registered" => "Non-registered".
  def kind_label
    self.class.kind_label_for(kind)
  end

  # Options for kind selects: [["TFSA", "tfsa"], ...].
  def self.kind_options
    KINDS.map { |k| [ kind_label_for(k), k ] }
  end

  def self.kind_label_for(kind)
    case kind
    when "tfsa", "rrsp", "resp", "fhsa" then kind.upcase
    else kind.to_s.tr("_", " ").capitalize
    end
  end
end
