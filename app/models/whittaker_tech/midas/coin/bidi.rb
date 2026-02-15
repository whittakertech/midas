# frozen_string_literal: true

# Bidi provides Unicode direction-isolation helpers so currency strings
# render correctly inside mixed LTR/RTL sentences.
#
# Uses Unicode isolation marks:
# - LRI U+2066
# - RLI U+2067
# - PDI U+2069
#
# NOTE: This does not *detect* direction from Money (Money doesn't carry it).
# This provides direction via options or configure Midas.currency_direction_for.
module WhittakerTech::Midas::Coin::Bidi
  LRI = "\u2066"
  RLI = "\u2067"
  PDI = "\u2069"

  # Wrap text in a direction-isolate span.
  #
  # dir: :ltr, :rtl, or nil (no wrapping)
  def bidi_isolate(text, dir:)
    return '' if text.nil?

    s = text.to_s
    return s if dir.nil?

    case dir
    when :ltr then "#{LRI}#{s}#{PDI}"
    when :rtl then "#{RLI}#{s}#{PDI}"
    else
      raise ArgumentError, "Unknown bidi dir: #{dir.inspect}"
    end
  end

  # A "safe default" for plain numbers in mixed-direction contexts.
  # Numbers are typically rendered LTR; isolating them prevents reordering.
  def bidi_isolate_number(text)
    bidi_isolate(text, dir: :ltr)
  end

  # Resolve the direction for a currency code.
  #
  # Override by passing `currency_dir:` to presenter methods, or configure:
  #   WhittakerTech::Midas.currency_directions["AED"] = :rtl
  def bidi_currency_dir(currency_code)
    WhittakerTech::Midas.currency_direction_for(currency_code)
  end
end
