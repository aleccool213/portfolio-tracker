module Products
  # Common identity and default roles for every product. Subclasses override
  # the roles that apply to them; callers should never need `record.kind`.
  class Base
    attr_reader :record

    delegate :id, :name, :institution, :to_param, :kind_label, to: :record

    def initialize(record)
      @record = record
    end

    # Does this product get a row on the value-entry page / count for check-in?
    def trackable?
      false
    end

    # Is this a valued sleeve that counts toward asset allocation?
    def asset?
      false
    end

    # This product's signed contribution to net worth.
    def net_worth_contribution
      0
    end

    # Formatted rate/term line for the dashboard card, or nil. Only mortgages
    # (so far) have one.
    def rate_line
      nil
    end

    def ==(other)
      other.is_a?(Products::Base) && other.record == record
    end
  end
end
