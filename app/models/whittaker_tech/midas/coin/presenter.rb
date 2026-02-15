# frozen_string_literal: true

# Presenter provides a strftime-like grammar for rendering Coins.
#
# - Declarative (token → method map)
# - Pure (no mutation, no rounding, no conversion)
# - Direction-safe via Coin::Bidi
#
# This object answers only one question:
#   "How should this Coin be shown to a human?"
module WhittakerTech::Midas::Coin::Presenter
  Context = Struct.new(
    :coin,
    :currency_dir,
    :approx,
    :units,
    :per_exact,
    keyword_init: true
  )

  # Public entrypoint
  def present(pattern, **)
    WhittakerTech::Midas::Coin::Presenter.format(self, pattern, **)
  end

  class << self
    # Registry of supported tokens.
    #
    # Each token maps to a private method on this module.
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

    # Main formatter
    def format(coin, pattern, **)
      raise ArgumentError, 'pattern required' if pattern.nil?

      ctx = build_context(coin, **)
      scan(pattern, ctx)
    end

    def build_context(coin, **opts)
      Context.new(coin:,
                  currency_dir: opts[:currency_dir] || coin.bidi_currency_dir(coin.currency_code),
                  approx: opts[:approx] || false,
                  units: opts[:units] || nil,
                  per_exact: opts[:per_exact] || nil)
    end

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

    def dispatch(token, ctx)
      handler = TOKEN_MAP[token]
      raise ArgumentError, "Unknown presenter token: %#{token}" unless handler

      send(handler, **ctx.to_h)
    end

    # -------------------------
    # Token implementations
    # -------------------------

    def token_percent(**)
      '%'
    end

    def token_total(coin:, currency_dir:, **)
      coin.bidi_isolate(coin.amount.format, dir: currency_dir)
    end

    def token_minor(coin:, **)
      coin.bidi_isolate_number(coin.currency_minor)
    end

    def token_major(coin:, **)
      coin.bidi_isolate_number(coin.major.to_s('F'))
    end

    def token_currency_code(coin:, **)
      # Currency codes are neutral; isolate as LTR for stability
      coin.bidi_isolate(coin.currency_code, dir: :ltr)
    end

    def token_currency_symbol(coin:, currency_dir:, **)
      symbol = Money::Currency.new(coin.currency_code).symbol
      coin.bidi_isolate(symbol, dir: currency_dir)
    end

    def token_number_only(coin:, **)
      # Best-effort extraction of the numeric portion
      formatted = coin.amount.format
      symbol = Money::Currency.new(coin.currency_code).symbol.to_s

      numberish =
        symbol.empty? ? formatted : formatted.gsub(symbol, '').strip

      coin.bidi_isolate_number(numberish)
    end

    def token_units(units:, **)
      units.nil? ? '' : units.to_s
    end

    def token_per_exact(per_exact:, **)
      per_exact.nil? ? '' : per_exact.to_s
    end

    def token_approx(approx:, **)
      approx ? '≈' : ''
    end
  end
end
