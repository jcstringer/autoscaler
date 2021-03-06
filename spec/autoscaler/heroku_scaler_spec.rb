require 'spec_helper'
require 'autoscaler/heroku_scaler'
require 'heroku/api/errors'

describe Autoscaler::HerokuScaler do
  let(:cut) {Autoscaler::HerokuScaler}
  let(:client) {cut.new}
  subject {client}

  describe "initialization" do
    let(:worker_name){ "not_worker" }

    around do |example|
      ENV['SIDEKIQ_WORKER_NAME'] = worker_name
      example.yield
      ENV['SIDEKIQ_WORKER_NAME'] = nil
    end
    
    its(:type) { should == worker_name }  
  end   

  describe "online", :online => true do
    its(:workers) {should == 0}
    its(:type) { should == "worker" } 

    describe 'scaled' do
      around do |example|
        client.workers = 1
        example.yield
        client.workers = 0
      end

      its(:workers) {should == 1}
    end

    shared_examples 'exception handler' do |exception_class|
      before do
        client.should_receive(:client){
          raise exception_class.new(Exception.new('oops'))
        }
      end

      describe "default handler" do
        it {expect{client.workers}.to_not raise_error}
        it {client.workers.should == 0}
        it {expect{client.workers = 2}.to_not raise_error}
      end

      describe "custom handler" do
        before do
          @caught = false
          client.exception_handler = lambda {|exception| @caught = true}
        end

        it {client.workers; @caught.should be_true}
      end
    end

    describe 'exception handling', :focus => true do
      it_behaves_like 'exception handler', Excon::Errors::SocketError
      it_behaves_like 'exception handler', Heroku::API::Errors::Error
    end
  end
end  