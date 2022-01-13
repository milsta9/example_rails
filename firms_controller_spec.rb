# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::AdminControllers::FirmsController, type: :controller do
  describe 'Get-index' do
    it_should_behave_like 'authorize admin' do
      let(:send_request) { get :index }
    end

    context 'when user is admin' do
      before do
        login_as_admin
        VCR.use_cassette 'googlemapapi' do
          2.times { create(:firm, checked: true) }
          2.times { create(:firm, checked: false) }
          create(:firm, name: 'example firm', checked: true)
        end
      end

      it 'paginates the result' do
        get :index, params: { perPage: 2 }
        expect(response.status).to eq 200
        expect(json_response['meta']['totalPages']).to eq 3
        expect(json_response['data'].length).to eq 2
      end

      it 'filters the result if the query is given' do
        get :index, params: { search: 'example' }
        expect(response.status).to eq 200
        expect(json_response['data'].length).to eq 1
      end

      it 'filters the checked firms if the query is checked' do
        get :index, params: { search: 'checked' }
        expect(response.status).to eq 200
        expect(json_response['data'].length).to eq 3
      end

      it 'filters the unchecked firms if the query is unchecked' do
        get :index, params: { search: 'unchecked' }
        expect(response.status).to eq 200
        expect(json_response['data'].length).to eq 2
      end
    end
  end

  describe 'Post-create' do
    it_should_behave_like 'authorize admin' do
      let(:send_request) { post :create }
    end

    context 'when user is admin' do
      let(:valid_params) {
        {
          name: 'Test Firm',
          phone_number: '1584757364',
          owner_id: @owner.id,
          status: :active,
          street: '15078, George 0Prairie',
          city: 'Kovacekfurt',
          state: 'Massachusetts'
        }
      }
      let(:invalid_params) {
        {
          name: '',
          phone_number: '',
          owner_id: nil
        }
      }

      before do
        login_as_admin
        @owner = VCR.use_cassette('stripe-customer-create') do
          create(:business)
        end
      end

      it 'creates firm if params are valid' do
        VCR.use_cassette 'googlemapapi' do
          post :create, params: valid_params
          expect(response.status).to eq 200
          expect(json_response['data']).not_to be_nil
        end
      end

      it 'returns error if params are not valid' do
        VCR.use_cassette 'googlemapapi' do
          post :create, params: invalid_params
          expect(response.status).to eq 200
          expect(json_response['errors'].any? { |error| error['title'] == 'Invalid name' }).to be true
        end
      end
    end
  end

  describe 'Patch-update' do
    before do
      VCR.use_cassette 'googlemapapi' do
        @firm = create(:firm)
      end
    end

    it_should_behave_like 'authorize admin' do
      let(:send_request) { patch :update, params: { id: @firm.id } }
    end

    context 'when user is admin' do
      let(:valid_params) {
        {
          name: 'Test Firm',
          phone_number: '1584757364'
        }
      }
      let(:invalid_params) {
        {
          name: '',
          phone_number: ''
        }
      }

      before do
        login_as_admin
      end

      it 'updates firm if params are valid' do
        VCR.use_cassette 'googlemapapi' do
          patch :update, params: valid_params.merge({ id: @firm.id })
          expect(response.status).to eq 200
          expect(json_response['data']).not_to be_nil
        end
      end

      it 'returns error if params are not valid' do
        VCR.use_cassette 'googlemapapi' do
          patch :update, params: invalid_params.merge({ id: @firm.id })
          expect(response.status).to eq 200
          expect(json_response['errors'].any? { |error| error['title'] == 'Invalid name' }).to be true
        end
      end

      it 'returns 404 if id is invalid' do
        patch :update, params: valid_params.merge({ id: 10000 })
        expect(response.status).to eq 404
      end
    end
  end

  describe 'Get-show' do
    before do
      VCR.use_cassette 'googlemapapi' do
        @firm = create(:firm)
      end
    end

    it_should_behave_like 'authorize admin' do
      let(:send_request) { get :show, params: { id: @firm.id } }
    end

    context 'when user is admin' do
      before do
        login_as_admin
      end

      it 'returns firm info if id is valid' do
        get :show, params: { id: @firm.id }
        expect(response.status).to eq 200
        expect(json_response['data']).not_to be_nil
      end

      it 'returns 404 if id is invalid' do
        get :show, params: { id: 10000 }
        expect(response.status).to eq 404
      end
    end
  end

  describe 'Delete-destroy' do
    before do
      VCR.use_cassette 'googlemapapi' do
        @firm = create(:firm)
      end
    end

    it_should_behave_like 'authorize admin' do
      let(:send_request) { delete :destroy, params: { id: @firm.id } }
    end

    context 'when user is admin' do
      before do
        login_as_admin
      end

      it 'destroys firm info if id is valid' do
        delete :destroy, params: { id: @firm.id }
        expect(response.status).to eq 204
        expect(Firm.count).to eq 0
      end

      it 'returns 404 if id is invalid' do
        delete :destroy, params: { id: 10000 }
        expect(response.status).to eq 404
      end
    end
  end
end
