class Account < ApplicationRecord
  # Broad grouping used for colour-coding and, later, allocation/risk views.
  # Registered accounts are the Canadian tax-sheltered ones (TFSA, RRSP, RESP...).
  KINDS = %w[tfsa rrsp resp fhsa non_registered crypto cash liability credit_card].freeze

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }

  # Human-friendly label for a kind, e.g. "non_registered" => "Non-registered".
  def kind_label
    case kind
    when "tfsa", "rrsp", "resp", "fhsa" then kind.upcase
    else kind.tr("_", " ").capitalize
    end
  end
end
