require 'spec_helper'

require_relative '../lib/message_helper'
# We don't check ordering of elements, because there are already tests for it.
module MessageHelpers
  describe RequestHelper do
    let(:request_helper) { RequestHelper.new }

    it "when created, should have empty request queue" do
      expect(request_helper).to have_empty_request_queue
    end

    it "can queue request without body" do
      expect do
        request_helper.queue_request :request_without_body
      end.not_to raise_error
    end

    it "can queue request with body" do
      expect do
        request_helper.queue_request :request_without_body, {}
      end.not_to raise_error
    end

    describe "when having empty request queue" do

      it "after queueing request, should have nonempty request queue" do
        request_helper.queue_request :request, {}
        expect(request_helper).not_to have_empty_request_queue
      end

      it "#shift should return a nil" do
        request_helper.shift_request
        expect(request_helper.shift_request).to be_nil
      end
    end

    describe "when having 2 requests in queue" do
      let(:fifo_ordered_requests) { [[:request1, {}], [:request2, {}]] }

      before(:each) do
        fifo_ordered_requests.each do |name, body|
          request_helper.queue_request name, body
        end
      end

      it "should have nonempty request queue" do
        expect(request_helper).not_to have_empty_request_queue
      end

      it "#shift should return exactly two times and then return nil." do
        expect { request_helper.shift_request }.not_to raise_error
        expect { request_helper.shift_request }.not_to raise_error
        expect(request_helper.shift_request).to be_nil
      end

      it "#shift should preserve FIFO ordering of requests" do
        queue_ordering = [request_helper.shift_request, request_helper.shift_request]
        expect(fifo_ordered_requests).to eq(queue_ordering)
      end
    end
  end
end
