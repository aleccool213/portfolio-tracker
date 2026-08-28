import { Controller } from "@hotwired/stimulus"

// Shows only the detail fields that belong to the selected account kind.
// Each group carries the kinds it applies to in data-kinds; the lists come
// from Products.kinds_for, so the mapping stays in one place server-side.
export default class extends Controller {
  static targets = ["kind", "group"]

  connect() {
    this.toggle()
  }

  toggle() {
    const kind = this.hasKindTarget ? this.kindTarget.value : ""

    this.groupTargets.forEach((group) => {
      const kinds = (group.dataset.kinds || "").split(" ")
      group.hidden = !kinds.includes(kind)
    })
  }
}
