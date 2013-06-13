require 'spec_helper'

describe Spree::Gateway::RecurlyGateway do
  let(:subdomain) { 'mydomain' }
  let(:api_key)   { 'xjkejid32djio' }

  let(:bill_address) {
    stub('Spree::Address',
      firstname: 'Tom',
      lastname: 'Smith',
      address1: '123 Happy Road',
      address2: 'Apt 303',
      city: 'Suzarac',
      zipcode: '95671',
      state: stub('Spree::State', name: 'Oregon'),
      country: stub('Spree::Country', name: 'United States')
    )
  }

  let(:payment) {
    stub('Spree::Payment',
      source: credit_card,
      order: stub('Spree::Order',
        email: 'smith@test.com',
        bill_address: bill_address,
        user: stub('Spree::User', id: 1)
      )
    )
  }

  before do
    subject.set_preference :subdomain, subdomain
    subject.set_preference :api_key, api_key
    subject.send(:update_recurly_config)
  end

  describe '#create_profile' do
    let(:credit_card) {
      stub('Spree::CreditCard',
        gateway_customer_profile_id: nil,
        number: '4111-1111-1111-1111',
        verification_value: '123',
        month: '11',
        year: '2015'
      ).as_null_object
    }

    context 'with an order that has a bill address' do

      it 'stores the bill address with the provider' do
        Recurly::Account.should_receive(:create).with({
          account_code: 1,
          email: 'smith@test.com',
          first_name: 'Tom',
          last_name: 'Smith',

          address: {
            address1: '123 Happy Road',
            address2: 'Apt 303',
            city: 'Suzarac',
            zip: '95671',
            country: 'United States',
            state: 'Oregon'
          },
          billing_info: {
            first_name: 'Tom',
            last_name:  'Smith',
            address1:   '123 Happy Road',
            address2:   'Apt 303',
            city:       'Suzarac',
            zip:        '95671',
            number:     '4111-1111-1111-1111',
            month:      '11',
            year:       '2015',
            verification_value: '123',
            country: 'United States',
            state: 'Oregon',
          }
        }).and_return(stub(account_code: payment.order.user.id, errors: nil))

        subject.create_profile payment
      end
    end
  end

  context 'with existing account' do
    let(:credit_card) {
      stub('Spree::CreditCard',
        gateway_customer_profile_id: 1,
        number: '4111-1111-1111-1111',
        verification_value: '123',
        month: '11',
        year: '2015'
      )
    }

    context 'purchasing' do

      it 'should send the payment to the provider' do
        account = stub.as_null_object
        Recurly::Account.should_receive(:find).with(1).and_return(account)

        account.transactions.should_receive(:create).with(
          :amount_in_cents => 19.99,
          :currency        => 'USD'
        ).and_return(stub.as_null_object)

        subject.purchase(19.99, credit_card, {})
      end

    end

    context 'voiding' do
      it 'should send the voiding to the provider' do
        transaction = stub.as_null_object
        Recurly::Transaction.should_receive(:find).with('a13acd8fe4294916b79aec87b7ea441f').and_return(transaction)

        transaction.should_receive(:refund).and_return(stub.as_null_object)

        subject.void('a13acd8fe4294916b79aec87b7ea441f', credit_card, {})
      end
    end

    context 'crediting' do
      it 'should send the crediting to the provider' do
        transaction = stub.as_null_object
        Recurly::Transaction.should_receive(:find).with('a13acd8fe4294916b79aec87b7ea441f').and_return(transaction)

        transaction.should_receive(:refund).with(50).and_return(stub.as_null_object)

        subject.credit(50, credit_card, 'a13acd8fe4294916b79aec87b7ea441f', {})
      end
    end

    context 'authorizing' do
      it 'should not support authorizing' do
        expect { subject.authorize(50, credit_card, {}) }.to raise_error
      end
    end

    context 'capturing' do
      it 'should not support capturing' do
        expect { subject.capture(payment, credit_card, {}) }.to raise_error
      end
    end
  end
end
