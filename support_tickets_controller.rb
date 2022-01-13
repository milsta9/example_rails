# frozen_string_literal: true

module V1
  module AdminControllers
    class SupportTicketsController < ::AdminController # :nodoc:
      before_action :set_support_ticket, only: %i[show update destroy]

      def index
        @q = SupportTicket.ransack
        set_search
        @support_tickets = sort_and_paginate(@q)
        meta_data = { currentPage: @support_tickets.current_page,
                      perPage: params[:perPage] || 10,
                      totalPages: @support_tickets.total_pages }

        render jsonapi: @support_tickets.uniq,
               include: %i[ticketable],
               meta: meta_data
      end

      def csv
        @q = SupportTicket.ransack
        set_search
        @support_tickets = @q.result
        render csv: send_data(@support_tickets.to_csv,
                              filename:
                                "support_tickets-#{Date.today}.csv") && return
      end

      # PATCH/PUT /support_tickets/1.json
      def update
        if @support_ticket.update(support_ticket_params)
          render jsonapi: @support_ticket
        else
          render jsonapi_errors: @support_ticket.errors
        end
      end

      # GET /support_tickets/1.json
      def show
        render jsonapi: @support_ticket, include: [:ticketable]
      end

      # DELETE /support_tickets/1.json
      def destroy
        @support_ticket.destroy
        head :no_content
      end

      private

      def set_search
        search = params[:search]
        return if search.blank?

        checked = nil
        if search == 'checked'
          checked = true
        elsif search == 'unchecked'
          checked = false
        end

        @q.build_grouping(search_conditions(search, checked))
      end

      def support_ticket_params
        params.permit(:status, :checked)
      end

      def set_support_ticket
        @support_ticket = SupportTicket.find(params[:id])
      end

      def search_conditions(search, checked)
        {
          m: 'or', id_eq: search, status_eq: search,
          ticketable_of_User_type_username_cont: search,
          ticketable_of_User_type_email_cont: search,
          ticketable_of_Business_type_username_cont: search,
          ticketable_of_Business_type_email_cont: search,
          ticketable_of_Admin_type_username_cont: search,
          ticketable_of_Admin_type_email_cont: search,
          checked_eq: checked, firm_name_cont: search
        }
      end
    end
  end
end
