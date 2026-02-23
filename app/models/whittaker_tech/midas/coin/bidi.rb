# frozen_string_literal: true

# Bidi provides Unicode bidirectional-text isolation helpers so that currency
# strings render correctly when embedded in mixed LTR/RTL sentences.
#
# ## Background
#
# In HTML, the Unicode Bidirectional Algorithm can reorder numeric and symbol
# characters in ways that produce confusing output when currency strings appear
# inside an RTL sentence (e.g. Arabic or Hebrew UI). Wrapping currency text in
# Unicode isolation marks prevents the algorithm from treating it as part of
# the surrounding paragraph direction.
#
# ## Isolation marks used
#
# Constants:
#
# - `LRI` (U+2066): Left-to-Right Isolate
# - `RLI` (U+2067): Right-to-Left Isolate
# - `PDI` (U+2069): Pop Directional Isolate (close)
#
# ## Direction configuration
#
# Currency direction defaults to `:ltr` for all currencies. Override per
# currency in an initializer:
#
#   WhittakerTech::Midas.currency_directions['ILS'] = :rtl
#   WhittakerTech::Midas.currency_directions['AED'] = :rtl
#
# See also: `WhittakerTech::Midas.currency_direction_for`
# @since 0.1.0
module WhittakerTech::Midas::Coin::Bidi
  # Unicode Left-to-Right Isolate mark (U+2066)
  LRI = "\u2066"

  # Unicode Right-to-Left Isolate mark (U+2067)
  RLI = "\u2067"

  # Unicode Pop Directional Isolate mark — closes an isolation span (U+2069)
  PDI = "\u2069"

  # Wraps `text` in a Unicode directional-isolate span.
  #
  # @param text [String, nil] the text to isolate; `nil` returns `""`
  # @param dir [Symbol, nil] `:ltr`, `:rtl`, or `nil` (no wrapping)
  # @return [String]
  # @raise [ArgumentError] if `dir` is not `:ltr`, `:rtl`, or `nil`
  #
  # @example
  #   bidi_isolate('$29.99', dir: :ltr)  # => "\u2066$29.99\u2069"
  #   bidi_isolate('29.99',  dir: nil)   # => "29.99"
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

  # Wraps a number string with LTR isolation.
  #
  # Numbers are always rendered LTR. This prevents the bidi algorithm from
  # reordering digit sequences when they appear in an RTL context.
  #
  # @param text [String, Integer, BigDecimal] the numeric value to isolate
  # @return [String]
  def bidi_isolate_number(text)
    bidi_isolate(text, dir: :ltr)
  end

  # Resolves the configured display direction for a currency code.
  #
  # Reads from `WhittakerTech::Midas.currency_directions`. Defaults to
  # `:ltr` for any currency not explicitly configured.
  #
  # @param currency_code [String] ISO 4217 currency code
  # @return [Symbol] `:ltr` or `:rtl`
  def bidi_currency_dir(currency_code)
    WhittakerTech::Midas.currency_direction_for(currency_code)
  end
end
