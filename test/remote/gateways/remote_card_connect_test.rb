require 'test_helper'

class RemoteCardConnectTest < Test::Unit::TestCase
  def setup
    @gateway = CardConnectGateway.new(fixtures(:card_connect))

    @amount = 100
    @credit_card = credit_card('4788250000121443')
    @declined_card = credit_card('4387751111111053')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
    @check = check
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approval', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com",
      po_number: '5FSD4',
      tax_amount: '50',
      freight_amount: '29',
      duty_amount: '67',
      order_date: '20170507',
      ship_from_date: '20877',
      items: [
        {
          line_no: '1',
          material: 'MATERIAL-1',
          description: 'DESCRIPTION-1',
          upc: 'UPC-1',
          quantity: '1000',
          uom: 'CS',
          unit_cost: '900',
          net_amnt: '150',
          tax_amnt: '117',
          disc_amnt: '0'
        },
        {
          line_no: '2',
          material: 'MATERIAL-2',
          description: 'DESCRIPTION-2',
          upc: 'UPC-1',
          quantity: '2000',
          uom: 'CS',
          unit_cost: '450',
          net_amnt: '300',
          tax_amnt: '117',
          disc_amnt: '0'
        }
      ]
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Approval', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Insufficient funds', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Approval Queued for Capture'|| 'Approval Accepted', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Insufficient funds', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '23221')
    assert_failure response
    assert_equal 'Txn not found', response.message
  end

   def test_successful_echeck_purchase
    response = @gateway.purchase(@amount, @check, @options)
    assert_equal 'Succeeded', response.message
    assert_success response
  end

  def test_failed_echeck_purchase
    response = @gateway.purchase(@amount, check(routing_number: "23433"), @options)
    assert_failure response
    assert response.message =~ /DECLINED/
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approval', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '23221')
    assert_failure response
    assert_equal 'Txn not found', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Approval', void.message
  end

  def test_failed_void
    response = @gateway.void('23221')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Approval}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Insufficient funds}, response.message
  end

  def test_invalid_login
    gateway = CardConnectGateway.new(username: '', password: '', merchant_id: '')
    assert_raises(ActiveMerchant::ResponseError) do 
      gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_dump_transcript
    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic.  You can delete
    # this helper after completing your scrub implementation.
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
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
