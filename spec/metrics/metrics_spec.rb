require 'spec_helper'

describe Influxer::Metrics do
  before do
    allow_any_instance_of(Influxer::Client).to receive(:query) do |_, sql|    
      sql
    end
  end

  let(:metrics) { Influxer::Metrics.new }
  let(:metrics_class) { Influxer::Metrics }


  # class methods

  specify {expect(metrics_class).to respond_to :attributes}  
  specify {expect(metrics_class).to respond_to :set_series}  
  specify {expect(metrics_class).to respond_to :series}  

  # query methods
  
  specify { expect(metrics_class).to respond_to :all}
  specify { expect(metrics_class).to respond_to :where}
  specify { expect(metrics_class).to respond_to :merge}
  specify { expect(metrics_class).to respond_to :time}
  specify { expect(metrics_class).to respond_to :past}
  specify { expect(metrics_class).to respond_to :since}
  specify { expect(metrics_class).to respond_to :limit}
  specify { expect(metrics_class).to respond_to :select}
  specify { expect(metrics_class).to respond_to :delete_all}

  # instance methods

  specify { expect(metrics).to respond_to :write }
  specify { expect(metrics).to respond_to :write! }
  specify { expect(metrics).to respond_to :persisted? }
  specify { expect(metrics).to respond_to :series}  


  # ActiveModel::Validations

  specify { expect(metrics).to respond_to :valid? }
  specify { expect(metrics).to respond_to :invalid? }
  specify { expect(metrics).to respond_to :errors }



  describe "instance methods" do

    let(:dummy_metrics) { DummyMetrics.new dummy_id: 1, user_id: 1}

    describe "#write" do

      context "Validations" do
        it "should not write if required attribute is missing" do
          m = DummyMetrics.new(dummy_id: 1)
          expect(m.write).to be false
          expect(m.errors.size).to eq(1)
        end 

        it "should raise error if required attribute is missing" do
          expect{DummyMetrics.new(user_id: 1).write!}.to raise_error(StandardError)    
        end 

        it "should raise error if you want to write twice" do
          expect(dummy_metrics.write).to be_truthy
          expect{dummy_metrics.write!}.to raise_error(StandardError)
        end
      end 

      it "should write successfully when all required attributes are set" do
        expect(Influxer.client).to receive(:write_point).with("dummy", anything)
        expect(dummy_metrics.write).to be_truthy
        expect(dummy_metrics.persisted?).to be_truthy
      end 
    end

    context "active_model callbacks" do
      it "should set current time" do
        Timecop.freeze(Time.local(2014,10,10,10,10,10)) do
          dummy_metrics.write!
        end
        expect(dummy_metrics.time).to eq Time.local(2014,10,10,10,10,10)
      end
    end

  end

  describe "class methods" do

    let(:dummy_metrics) do
      Class.new(Influxer::Metrics) do
        set_series :dummies       
        attributes :user_id, :dummy_id 
      end
    end

    let(:dummy_metrics_2) do
      Class.new(Influxer::Metrics) do
        set_series "dummy \"A\""       
      end
    end

    let(:dummy_metrics_3) do
      Class.new(Influxer::Metrics) do
        set_series /^.*$/       
      end
    end

    let(:dummy_with_2_series) do
      Class.new(Influxer::Metrics) do
        set_series :events, :errors       
      end
    end

    let(:dummy_with_2_series_quoted) do
      Class.new(Influxer::Metrics) do
        set_series "dummy \"A\"", "dummy \"B\""        
      end
    end

    let(:dummy_with_proc_series) do
      Class.new(Influxer::Metrics) do
        attributes :user_id, :test_id
        set_series ->(metrics) { "test/#{metrics.test_id}/user/#{metrics.user_id}"}       
      end
    end

    describe "set_series" do
      it "should set series name from class name by default" do
        expect(DummyMetrics.new.series).to eq "\"dummy\""
      end

      it "should set series from subclass" do
        expect(dummy_metrics.new.series).to eq "\"dummies\""
      end

      it "should set series as regexp" do
        expect(dummy_metrics_3.new.series).to eq '/^.*$/'
      end

      it "should set series with quotes" do
        expect(dummy_metrics_2.new.series).to eq "\"dummy \\\"A\\\"\""
      end

      it "should set several series" do
        expect(dummy_with_2_series.new.series).to eq "merge(\"events\",\"errors\")"
      end

      it "should set several series with quotes" do
        expect(dummy_with_2_series_quoted.new.series).to eq "merge(\"dummy \\\"A\\\"\",\"dummy \\\"B\\\"\")"
      end

      it "should set series from proc" do
        expect(dummy_with_proc_series.series).to be_an_instance_of Proc

        m = dummy_with_proc_series.new user_id: 2, test_id:123
        expect(m.series).to eq "\"test/123/user/2\""
      end
    end

    describe "write method" do
      it "should write data and return point" do
        expect(Influxer.client).to receive(:write_point).with("dummies", {user_id: 1, dummy_id: 2})
        
        point = dummy_metrics.write(user_id: 1, dummy_id: 2)
        expect(point.persisted?).to be_truthy
        expect(point.user_id).to eq 1
        expect(point.dummy_id).to eq 2
      end 

      it "should not write data and return false" do
        expect(DummyMetrics.write(dummy_id: 2)).to be false
      end 
    end

    describe "all method" do
      it "should respond with relation" do
        expect(metrics_class.all).to be_an_instance_of Influxer::Relation
      end
    end

  end
end