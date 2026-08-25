# Labels and before → after cells for the import preview table.
module ImportsHelper
  ACTION_LABELS = { create: "Create", update: "Update", keep: "Keep" }.freeze
  ACTION_BADGE = { create: "badge-up", update: "badge-update", keep: "badge-flat" }.freeze

  # Pill for :create / :update / :keep. Hidden for :none or a missing action.
  def import_action_badge(action)
    return if action.nil? || action == :none

    tag.span(ACTION_LABELS.fetch(action), class: "badge #{ACTION_BADGE.fetch(action)}")
  end

  # CSV line number from row.origin ("Line 3" → "3"), or an em dash.
  def import_line_number(entry)
    entry.row.origin.to_s.delete_prefix("Line ").presence || "—"
  end

  def import_account_label(entry)
    [ entry.row.name, entry.row.institution ].compact_blank.join(" · ")
  end

  # "Name: Managed TFSA → Renamed TFSA · Kind: tfsa → rrsp"
  def import_account_changes(entry)
    entry.account_changes.map { |field, (old_v, new_v)|
      "#{field.humanize}: #{old_v.presence || '—'} → #{new_v.presence || '—'}"
    }.join(" · ")
  end

  # "Jan 2026", or "Jan 2026 → Feb 2026" when the snapshot date would move.
  def import_month_cell(entry)
    if entry.value_changes["recorded_on"]
      old_d, new_d = entry.value_changes["recorded_on"]
      "#{old_d.strftime('%b %Y')} → #{new_d.strftime('%b %Y')}"
    elsif entry.row.recorded_on
      date = entry.row.recorded_on
      date = date.is_a?(Date) ? date : Date.parse(date.to_s)
      date.strftime("%b %Y")
    else
      "—"
    end
  end

  # Whole-dollar amount, or "old → new" when the snapshot amount would change.
  def import_amount_cell(entry)
    if entry.value_changes["amount"]
      old_a, new_a = entry.value_changes["amount"]
      "#{formatted_amount(old_a)} → #{formatted_amount(new_a)}"
    elsif entry.row.amount
      formatted_amount(entry.row.amount)
    else
      "—"
    end
  end
end
