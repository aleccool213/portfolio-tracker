# Read-only tool surface for an MCP server (or any LLM agent).
# No writes — list accounts, values, net worth, and allocation only.
class PortfolioMcp
  Tool = Data.define(:name, :description, :input_schema)

  TOOLS = [
    Tool.new(
      name: "list_accounts",
      description: "List household accounts with kind, institution, and current amount.",
      input_schema: { type: "object", properties: {}, additionalProperties: false }
    ),
    Tool.new(
      name: "get_account_values",
      description: "Monthly snapshots for one account, oldest first.",
      input_schema: {
        type: "object",
        properties: {
          account_id: { type: "integer", description: "Account id" }
        },
        required: [ "account_id" ],
        additionalProperties: false
      }
    ),
    Tool.new(
      name: "net_worth",
      description: "Current household net worth (assets minus liabilities; credit cards excluded).",
      input_schema: { type: "object", properties: {}, additionalProperties: false }
    ),
    Tool.new(
      name: "allocation",
      description: "Asset allocation by account kind plus gentle concentration nudges.",
      input_schema: { type: "object", properties: {}, additionalProperties: false }
    )
  ].freeze

  def tools
    TOOLS
  end

  def call(name, arguments = {})
    args = arguments.transform_keys(&:to_s)

    case name
    when "list_accounts" then list_accounts
    when "get_account_values" then get_account_values(args.fetch("account_id"))
    when "net_worth" then net_worth
    when "allocation" then allocation
    else
      { error: "Unknown tool: #{name}" }
    end
  end

  private

  def accounts
    Account.includes(:account_values).order(:kind, :name)
  end

  def list_accounts
    accounts.map do |account|
      {
        id: account.id,
        name: account.name,
        institution: account.institution,
        kind: account.kind,
        current_amount: account.current_amount&.to_f,
        credit_card: account.credit_card?,
        mortgage: account.mortgage?
      }
    end
  end

  def get_account_values(account_id)
    account = Account.find(account_id)
    {
      account_id: account.id,
      name: account.name,
      values: account.account_values.chronological.map { |v|
        { recorded_on: v.recorded_on.iso8601, amount: v.amount.to_f }
      }
    }
  end

  def net_worth
    portfolio = Portfolio.new(accounts)
    {
      net_worth: portfolio.net_worth.to_f,
      needs_check_in: portfolio.needs_check_in?
    }
  end

  def allocation
    alloc = Allocation.new(accounts)
    {
      total_assets: alloc.total_assets.to_f,
      slices: alloc.slices.map { |s|
        { kind: s.kind, label: s.label, amount: s.amount.to_f, pct: s.pct }
      },
      nudges: alloc.nudges.map(&:message)
    }
  end
end
