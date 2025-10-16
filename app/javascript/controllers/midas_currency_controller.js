// WhittakerTech::Midas Currency Input Controller
// Provides bank-style currency input behavior where each digit shifts left
// Example: typing "1234" results in "12.34" (for 2 decimal currencies)

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "hidden"]
  static values = {
    currency: String,
    decimals: { type: Number, default: 2 }
  }

  connect() {
    this.updateDisplay()
  }

  // Bank-style typing: each digit shifts left
  input(event) {
    const key = event.data

    if (!key || !/^\d$/.test(key)) {
      event.preventDefault()
      return
    }

    let current = parseInt(this.hiddenTarget.value || "0")
    current = (current * 10) + parseInt(key)

    this.hiddenTarget.value = current
    this.updateDisplay()
  }

  // Backspace removes the rightmost digit
  backspace(event) {
    if (event.key === "Backspace") {
      event.preventDefault()
      let current = parseInt(this.hiddenTarget.value || "0")
      current = Math.floor(current / 10)
      this.hiddenTarget.value = current
      this.updateDisplay()
    }
  }

  // Format minor units as major units with decimals
  updateDisplay() {
    const minor = parseInt(this.hiddenTarget.value || "0")
    const divisor = Math.pow(10, this.decimalsValue)
    const amount = (minor / divisor).toFixed(this.decimalsValue)

    this.displayTarget.value = amount
  }

  // Prevent default typing, force bank-style
  preventDefault(event) {
    if (event.key !== "Tab" && event.key !== "Backspace") {
      event.preventDefault()
    }
  }
}