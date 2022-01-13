# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::SupportTicketsController, type: :controller do
  describe 'Get-index' do
    it_should_behave_like 'authorize user' do
      let(:send_request) { get :index }
    end

    context 'when user is logged in' do
      before do
        user = login_as_user
        other_user = create(:user)
        5.times { create(:support_ticket, ticketable: user) }
        5.times { create(:support_ticket, ticketable: other_user) }
      end

      it 'paginates the result' do
        get :index, params: { perPage: 2 }
        expect(response.status).to eq 200
        expect(json_response['meta']['totalPages']).to eq 3
        expect(json_response['data'].length).to eq 2
      end
    end
  end

  describe 'Get-show' do
    it_should_behave_like 'authorize user' do
      let(:send_request) { get :show, params: { id: 10000 } }
    end

    context 'when user is logged in' do
      before do
        user = login_as_user
        other_user = create(:user)
        @ticket = create(:support_ticket, ticketable: user)
        @other_ticket = create(:support_ticket, ticketable: other_user)
      end

      it 'returns ticket info if id is valid' do
        get :show, params: { id: @ticket.id }
        expect(response.status).to eq 200
        expect(json_response['data']).not_to be_nil
      end

      it 'returns 404 if id is invalid' do
        get :show, params: { id: @other_ticket.id }
        expect(response.status).to eq 404
      end
    end
  end

  describe 'Post-create' do
    it_should_behave_like 'authorize user' do
      let(:send_request) { post :create }
    end

    context 'when user is logged in' do
      before do
        @user = login_as_user
      end

      it 'creates ticket if params are valid' do
        post :create, params: { query: 'example ticket' }
        expect(response.status).to eq 201
        expect(json_response['data']).not_to be_nil
        expect(@user.support_tickets.length).to eq 1
      end

      it 'returns error if params are invalid' do
        post :create, params: { query: nil }
        expect(response.status).to eq 422
        expect(json_response['errors'].any? { |error| error['title'] == 'Invalid query' }).to be true
      end
    end
  end

  describe 'Patch-update' do
    it_should_behave_like 'authorize user' do
      let(:send_request) { patch :update, params: { id: 10000 } }
    end

    context 'when user is logged in' do
      before do
        user = login_as_user
        other_user = create(:user)
        @ticket = create(:support_ticket, ticketable: user)
        @other_ticket = create(:support_ticket, ticketable: other_user)
      end

      it 'updates ticket if param is valid' do
        patch :update, params: { id: @ticket.id, query: 'example ticket' }
        expect(response.status).to eq 200
        expect(json_response['data']).not_to be_nil
      end

      it 'returns error if param is invalid' do
        patch :update, params: { id: @ticket.id, query: nil }
        expect(response.status).to eq 422
        expect(json_response['errors'].any? { |error| error['title'] == 'Invalid query' }).to be true
      end

      it 'returns 404 if id is invalid' do
        patch :update, params: { id: @other_ticket.id }
        expect(response.status).to eq 404
      end
    end
  end

  describe 'Delete-destroy' do
    it_should_behave_like 'authorize user' do
      let(:send_request) { delete :destroy, params: { id: 10000 } }
    end

    context 'when user is logged in' do
      before do
        @user = login_as_user
        other_user = create(:user)
        @ticket = create(:support_ticket, ticketable: @user)
        @other_ticket = create(:support_ticket, ticketable: other_user)
      end

      it 'destroys ticket info if id is valid' do
        delete :destroy, params: { id: @ticket.id }
        expect(response.status).to eq 204
        expect(@user.support_tickets.count).to eq 0
      end

      it 'returns 404 if id is invalid' do
        delete :destroy, params: { id: @other_ticket.id }
        expect(response.status).to eq 404
      end
    end
  end
end
