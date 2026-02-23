# frozen_string_literal: true

# Presenter provides a strftime-like token grammar for rendering `Coin` values.
#
# ## Design principles
#
# - **Declarative** — tokens map directly to named handler methods.
# - **Pure** — no mutation, rounding, or currency conversion.
# - **Direction-safe** — all text is wrapped with Unicode bidirectional
#   isolation markers via `Coin::Bidi` to prevent display corruption in
#   mixed LTR/RTL contexts.
#
# ## Token reference
#
# Patterns are strings containing `%x` tokens (similar to `strftime`).
#
# Tokens:
#
# - `%t`: Formatted total (symbol + amount), e.g. `$29.99`
# - `%m`: Minor units (raw integer), e.g. `2999`
# - `%M`: Major units (decimal string), e.g. `29.99`
# - `%c`: Currency code, e.g. `USD`
# - `%s`: Currency symbol, e.g. `$`
# - `%n`: Number only (no symbol), e.g. `29.99`
# - `%u`: Custom units label (see opts), e.g. `per kg`
# - `%p`: Custom per-exact label (see opts), e.g. `0.2997`
# - `~`: Approximate marker (`≈` or empty)
# - `%%`: Literal percent sign
#
# ## Usage
#
#   coin = Coin.value(2999, 'USD')
#   coin.present('%s%M %c')          # => "$29.99 USD"
#   coin.present('~%t', approx: true) # => "≈$29.99"
#
# ## Options
#
# Pass keyword options to `present` / `format` to populate optional tokens:
#
# - `approx:` [Boolean] — if true, `~` expands to `≈`; otherwise empty string.
# - `units:` [String] — value for `%u` token.
# - `per_exact:` [String] — value for `%p` token.
# - `currency_dir:` [Symbol] — override the currency display direction
#   (`:ltr` or `:rtl`); defaults to the value from
#   `WhittakerTech::Midas.currency_direction_for`.
#
# @since 0.1.0
module WhittakerTech::Midas::Coin::Presenter
  # Internal rendering context. Populated from the Coin and caller-supplied options.
  # @!visibility private
  Context = Struct.new(
    :coin,
    :currency_dir,
    :approx,
    :units,
    :per_exact,
    keyword_init: true
  )

  # Renders this Coin using a format pattern.
  #
  # @param pattern [String] the format pattern containing `%x` tokens
  # @param opts [Hash] optional rendering context overrides (see module docs)
  # @return [String]
  # @raise [ArgumentError] if the pattern contains an unknown or unterminated token
  #
  # @example
  #   coin.present('%s%M')          # => "$29.99"
  #   coin.present('%t (%c)')       # => "$29.99 (USD)"
  #   coin.present('~%t', approx: true) # => "≈$29.99"
  def present(pattern, **opts)
    WhittakerTech::Midas::Coin::Presenter.format(self, pattern, **opts)
  end

  class << self
    # Registry of recognised tokens and their handler method names.
    #
    # @return [Hash{String => Symbol}]
    TOKEN_MAP = {
      '%' => :token_percent,
      't' => :token_total,
      'm' => :token_minor,
      'M' => :token_major,
      'c' => :token_currency_code,
      's' => :token_currency_symbol,
      'n' => :token_number_only,
      'u' => :token_units,
      'p' => :token_per_exact,
      '~' => :token_approx
    }.freeze

    # Formats a Coin using a pattern string.
    #
    # This is the class-level entry point; instance-level access is via
    # `Coin#present`.
    #
    # @param coin [Coin] the value to format
    # @param pattern [String] the format pattern
    # @param opts [Hash] optional context overrides
    # @return [String]
    # @raise [ArgumentError] if `pattern` is nil, contains an unknown token,
    #   or has an unterminated `%` escape
    def format(coin, pattern, **opts)
      raise ArgumentError, 'pattern required' if pattern.nil?

      ctx = build_context(coin, **opts)
      scan(pattern, ctx)
    end

    # Builds a `Context` struct from a Coin and caller-supplied options.
    #
    # @param coin [Coin]
    # @param opts [Hash]
    # @option opts [Symbol] :currency_dir (:ltr or :rtl) override direction
    # @option opts [Boolean] :approx whether to render `~` as `≈`
    # @option opts [String, nil] :units value for `%u` token
    # @option opts [String, nil] :per_exact value for `%p` token
    # @return [Context]
    def build_context(coin, **opts)
      Context.new(coin:,
                  currency_dir: opts[:currency_dir] || coin.bidi_currency_dir(coin.currency_code),
                  approx: opts[:approx] || false,
                  units: opts[:units] || nil,
                  per_exact: opts[:per_exact] || nil)
    end

    # Scans a pattern string, expanding `%x` tokens into rendered values.
    #
    # @param pattern [String]
    # @param ctx [Context]
    # @return [String]
    # @raise [ArgumentError] on unknown or unterminated tokens
    def scan(pattern, ctx)
      is_token = false
      out = +'' # output buffer

      pattern.to_s.each_char do |char|
        if is_token
          out << dispatch(char, ctx)
          is_token = false
        elsif char == '%'
          is_token = true
        else
          out << char
        end
      end

      raise ArgumentError, "Unterminated token in pattern: #{pattern}" if is_token

      out
    end

    # Dispatches a single token character to its handler.
    #
    # @param token [String] single character following `%`
    # @param ctx [Context]
    # @return [String]
    # @raise [ArgumentError] if the token is not in `TOKEN_MAP`
    def dispatch(token, ctx)
      handler = TOKEN_MAP[token]
      raise ArgumentError, "Unknown presenter token: %#{token}" unless handler

      send(handler, **ctx.to_h)
    end

    # -------------------------
    # Token implementations
    # -------------------------

    # @api private
    def token_percent(**)
      '%'
    end

    # @api private
    def token_total(coin:, currency_dir:, **)
      coin.bidi_isolate(coin.amount.format, dir: currency_dir)
    end

    # @api private
    def token_minor(coin:, **)
      coin.bidi_isolate_number(coin.currency_minor)
    end

    # @api private
    def token_major(coin:, **)
      coin.bidi_isolate_number(coin.major.to_s('F'))
    end

    # @api private
    def token_currency_code(coin:, **)
      # Currency codes are neutral; isolate as LTR for stability
      coin.bidi_isolate(coin.currency_code, dir: :ltr)
    end

    # @api private
    def token_currency_symbol(coin:, currency_dir:, **)
      symbol = Money::Currency.new(coin.currency_code).symbol
      coin.bidi_isolate(symbol, dir: currency_dir)
    end

    # @api private
    def token_number_only(coin:, **)
      # Best-effort extraction of the numeric portion
      formatted = coin.amount.format
      symbol = Money::Currency.new(coin.currency_code).symbol.to_s

      numberish =
        symbol.empty? ? formatted : formatted.gsub(symbol, '').strip

      coin.bidi_isolate_number(numberish)
    end

    # @api private
    def token_units(units:, **)
      units.nil? ? '' : units.to_s
    end

    # @api private
    def token_per_exact(per_exact:, **)
      per_exact.nil? ? '' : per_exact.to_s
    end

    # @api private
    def token_approx(approx:, **)
      approx ? '≈' : ''
    end
  end
end
