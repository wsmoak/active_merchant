module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class YourpayGateway < Gateway
      self.test_url = 'https://webservice.yourpay.dk/v4/'
      self.live_url = 'https://webservice.yourpay.dk/v4/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.yourpay.io/'
      self.display_name = 'YourPay'

      def initialize(options={})
        requires!(options, :merchant_id)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)

        commit('process_payment', post)
      end

      def void(authorization, options={})
        post = {}
        tid, _paymentid, time = authorization.split('|')
        post[:paymentid] = tid
        post[:timeid] = time
        commit('reverse_transaction', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub('(merchantid=)\d+', '\1[FILTERED]')
          .gsub('(cvc=)\d+', '\1[FILTERED]')
          .gsub('(cardno=)\d+', '\1[FILTERED]')
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
        post[:cardholder] = payment.name
        post[:cvc] = payment.verification_value
        post[:expyear] = payment.year
        post[:expmonth] = payment.month
        post[:cardno] = payment.number
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters)
        url = "#{(test? ? test_url : live_url)}#{action}"
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response['status'] == 'ACK'
      end

      def authorization_from(response)
        [response['tid'], response['PaymentID'], response['time']].join('|')
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def message_from(response)
        response['Transaction'] || response['reason'] || response['status']
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE[:processing_error] unless success_from(response)
      end

      def post_data(_action, parameters = {})
        parameters[:merchantid] = @options[:merchant_id]
        parameters.map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join('&')
      end
    end
  end
end
