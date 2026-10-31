class CoreMcp::Catalog::Price
  DEFAULT_CURRENCY = 'SEK'.freeze #: ::String

  # @rbs (::Hash[::String, untyped] data) -> void
  def initialize(data)
    @data = data
  end

  # @rbs () -> CoreMcp::price
  def payload
    discount = @data.fetch('discount')

    {
      total_minor: as_cents(discount.fetch('totalPrice')),
      unit_price_minor: as_cents(discount.fetch('price')),
      cleaning_fee_minor: @data['cleaningFee'] && as_cents(@data.fetch('cleaningFee')),
      status: 'estimated',
      currency: @data.fetch('currency'),
      unit: @data.fetch('unit'),
      guest_fees:,
      payment_schedule: schedule(@data.fetch('paymentSchedule')),
      inventory_held: false,
      start_date: @data.fetch('startDate'),
      end_date: @data.fetch('endDate')
    }
  end

  # @rbs (::String status) -> CoreMcp::price
  def self.empty(status)
    {
      status:,
      currency: DEFAULT_CURRENCY,
      total_minor: nil,
      unit: nil,
      unit_price_minor: nil,
      cleaning_fee_minor: nil,
      guest_fees: [],
      payment_schedule: [],
      inventory_held: false,
      start_date: nil,
      end_date: nil
    }
  end

  private

  # @rbs () -> ::Array[::Hash[::Symbol, untyped]]
  def guest_fees
    @data.fetch('calculatedGuestFees').map do |fee|
      {
        name: fee.fetch('name'),
        amount_minor: as_cents(fee.fetch('price'))
      }
    end
  end

  # @rbs (::Array[::Hash[::String, untyped]] payments) -> ::Array[::Hash[::Symbol, untyped]]
  def schedule(payments)
    payments.map do |payment|
      {
        payment_date: payment.fetch('paymentDate'),
        from: payment.fetch('from'),
        to: payment.fetch('to'),
        amount_minor: as_cents(payment.fetch('discountedPrice') + payment.fetch('cleaningFee'))
      }
    end
  end

  # @rbs ((::Integer | ::Float) value) -> ::Integer
  def as_cents(value)
    (value.to_f * 100).round
  end
end
