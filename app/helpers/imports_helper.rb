module ImportsHelper
  ACTION_LABELS = { create: "Create", update: "Update", keep: "Keep" }.freeze
  ACTION_BADGE = { create: "badge-up", update: "badge-update", keep: "badge-flat" }.freeze

  def import_action_badge(action)
    return if action.nil? || action == :none

    tag.span(ACTION_LABELS.fetch(action), class: "badge #{ACTION_BADGE.fetch(action)}")
  end

  def import_line_number(entry)
    entry.row.origin.to_s.delete_prefix("Line ").presence || "—"
  end

  def import_account_label(entry)
    [ entry.row.name, entry.row.institution ].compact_blank.join(" · ")
  end

  def import_account_changes(entry)
    entry.account_changes.map { |field, (old_v, new_v)|
      "#{field.humanize}: #{old_v.presence || '—'} → #{new_v.presence || '—'}"
    }.join(" · ")
  end

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
