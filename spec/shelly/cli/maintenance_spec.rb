require 'spec_helper'
require 'shelly/cli/maintenance'

describe Shelly::CLI::Maintenance do
  let!(:cli) { Shelly::CLI::Maintenance.new }
  let!(:app) { Shelly::App.new('foo-production') }
  let!(:client) { mock }

  before do
    Shelly::CLI::Maintenance.stub(:new).and_return(cli)
    Shelly::Client.stub(:new).and_return(client)
    client.stub(:authorize!)
    FileUtils.mkdir_p('/projects/foo')
    Dir.chdir('/projects/foo')
    Shelly::App.stub(:new).and_return(app)
    File.open('Cloudfile', 'w') { |f| f.write("foo-production:\n") }
  end

  describe '#list' do
    it 'should ensure user has logged in' do
      hooks(cli, :list).should include(:logged_in?)
    end

    context 'when cloud have maintenances' do
      before do
        app.should_receive(:maintenances).and_return([{
          'description'=>'Testing',
          'user'=>'user@example.com',
          'created_at'=>'2014-07-03T09:45:42+02:00',
          'updated_at'=>'2014-07-03T09:45:42+02:00',
          'finished'=>false
        }, {
          'description'=>'Short maintenance',
          'user'=>'user@example.com',
          'created_at'=>'2014-07-02T13:32:07+02:00',
          'updated_at'=>'2014-07-02T13:32:40+02:00',
          'finished'=>true
        }])
      end

      it 'should print list of last maintenance events' do
        $stdout.should_receive(:puts).
          with(green 'Recent application maintenance events')
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).
          with(" * #{local_time('2014-07-03T09:45:42+02:00')} - in progress")
        $stdout.should_receive(:puts).
          with('   Testing')
        $stdout.should_receive(:puts).with("\n")
        $stdout.should_receive(:puts).
          with(" * #{local_time('2014-07-02T13:32:07+02:00')} -" \
            " #{local_time('2014-07-02T13:32:40+02:00')}")
        $stdout.should_receive(:puts).
          with('   Short maintenance')
        $stdout.should_receive(:puts).with("\n")

        invoke(cli, :list)
      end

      private

      def local_time(date)
        Time.parse(date).getlocal.strftime('%Y-%m-%d %H:%M:%S')
      end
    end

    context 'when cloud does not have any maintenance events' do
      before do
        client.stub(:maintenances).and_return([])
      end

      it 'should show message' do
        $stdout.should_receive(:puts).
          with('There are no maintenance events for foo-production')
        invoke(cli, :list)
      end
    end
  end

  describe '#start' do
    it 'should ensure user has logged in' do
      hooks(cli, :start).should include(:logged_in?)
    end

    it 'should start new maintenance' do
      client.should_receive(:start_maintenance).
        with('foo-production', {:description=>'Test'})
      $stdout.should_receive(:puts).with(green 'Maintenance has been started')
      invoke(cli, :start, 'Test')
    end

    context 'on failure' do
      context 'because description is missed' do
        before do
          body = {
            'message' => 'Validation Failed',
            'errors' => [['description', "can't be blank"]]
          }
          exception = Shelly::Client::ValidationException.new(body)
          client.stub(:start_maintenance).and_raise(exception)
        end

        it 'should print error message' do
          $stdout.should_receive(:puts).with(red "Description can't be blank")
          invoke(cli, :start)
        end
      end

      context 'because there is another maintenance in progress' do
        before do
          body = {
            'message' => 'Maintenance is already in progress'
          }
          exception = Shelly::Client::ConflictException.new(body)
          client.stub(:start_maintenance).and_raise(exception)
        end

        it 'should print error message' do
          $stdout.should_receive(:puts).
            with(red 'Maintenance is already in progress')

          lambda {
            invoke(cli, :start)
          }.should raise_error(SystemExit)
        end
      end
    end
  end

  describe '#finish' do
    it 'should ensure user has logged in' do
      hooks(cli, :finish).should include(:logged_in?)
    end

    it 'should finish last maintenance' do
      client.should_receive(:finish_maintenance).
        with('foo-production')
      $stdout.should_receive(:puts).with(green 'Maintenance has been finished')
      invoke(cli, :finish)
    end

    context 'on failure' do
      context 'because there is no maintenances in progress' do
        before do
          body = {
            'message' => 'There is no maintenance events in progress'
          }
          exception = Shelly::Client::ConflictException.new(body)
          client.stub(:finish_maintenance).and_raise(exception)
        end

        it 'should print error message' do
          $stdout.should_receive(:puts).
            with(red 'There is no maintenance events in progress')

          lambda {
            invoke(cli, :finish)
          }.should raise_error(SystemExit)
        end
      end
    end
  end
end
