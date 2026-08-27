class Account < ApplicationRecord
  # Broad grouping used for colour-coding and, later, allocation/risk views.
  # Registered accounts are the Canadian tax-sheltered ones (TFSA, RRSP, RESP...).
  KINDS = %w[tfsa rrsp resp fhsa non_registered crypto cash liability credit_card].freeze

  has_many :account_values, dependent: :destroy

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }

  # Liability-only details (mortgage rate, term, original principal).
  validates :interest_rate, :term_months, :original_principal,
            presence: true, if: :liability_kind?
  validates :interest_rate, numericality: { greater_than: 0 }, if: -> { liability_kind? && interest_rate.present? }
  validates :term_months, numericality: { only_integer: true, greater_than: 0 },
            if: -> { liability_kind? && term_months.present? }
  validates :original_principal, numericality: { greater_than: 0 },
            if: -> { liability_kind? && original_principal.present? }

  # The most recent monthly snapshot, or nil if none recorded yet.
  def latest_value
    if account_values.loaded?
      account_values.max_by(&:recorded_on)
    else
      account_values.order(recorded_on: :desc).first
    end
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

  private

  def liability_kind?
    kind == "liability"
  end
end
