require 'test_helper'

class RemoteYourpayTest < Test::Unit::TestCase
  def setup
    @gateway = YourpayGateway.new(fixtures(:yourpay))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @options = {}
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'ACK', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com'
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'ACK', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, {currency: 'petunias'})
    assert_failure response
    assert_equal 'Transaction could not be verified', response.message
  end

  def test_successful_void
    auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'REPLACE WITH SUCCESSFUL VOID MESSAGE', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  end

  def test_invalid_login
    gateway = YourpayGateway.new(merchant_id: 'bogus id')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'MerchantID not found', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

end
