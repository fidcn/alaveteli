# -*- encoding : utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'fakeweb'

describe ServicesController, "when returning a message for people in other countries" do

  render_views

  # store and restore the locale in the context of the test suite to isolate
  # changes made in these tests
  before do
    @old_locale = FastGettext.locale
  end

  it 'keeps the flash' do
    # Make two get requests to simulate the flash getting swept after the
    # first response.
    get :other_country_message, nil, nil, :some_flash_key => 'abc'
    get :other_country_message
    expect(flash[:some_flash_key]).to eq('abc')
  end

  it "should show no alaveteli message when in the deployed country" do
    config = MySociety::Config.load_default
    config['ISO_COUNTRY_CODE'] = "DE"
    allow(controller).to receive(:country_from_ip).and_return('DE')
    get :other_country_message
    expect(response.body).to eq("")
  end

  it "should show an alaveteli message when not in the deployed country and in a country with no FOI website" do
    config = MySociety::Config.load_default
    config['ISO_COUNTRY_CODE'] = "DE"
    allow(controller).to receive(:country_from_ip).and_return('ZZ')
    get :other_country_message
    expect(response.body).to match(/outside Deutschland/)
  end

  it "should show link to other FOI website when not in the deployed country" do
    config = MySociety::Config.load_default
    config['ISO_COUNTRY_CODE'] = "ZZ"
    allow(controller).to receive(:country_from_ip).and_return('ES')
    request.env['HTTP_ACCEPT_LANGUAGE'] = "es"
    get :other_country_message
    expect(response.body).to match(/Puede hacer solicitudes de información en España/)
  end

  after do
    FastGettext.set_locale(@old_locale)
  end

  describe 'when the external country from IP service is in different states' do

    before (:each) do
      FakeWeb.clean_registry
      config = use_gaze_instead_of_geoip_db!
    end

    after (:each) do
      FakeWeb.clean_registry
      MySociety::Config.load_default
    end

    it "should return the 'another country' message if the service responds OK" do
      config['ISO_COUNTRY_CODE'] = "DE"
      allow(AlaveteliConfiguration).to receive(:gaze_url).and_return('http://denmark.com')
      FakeWeb.register_uri(:get, %r|denmark.com|, :body => "DK")
      get :other_country_message
      expect(response).to be_success
      expect(response.body).to eq('Hello! We have an  <a href="/help/alaveteli?country_name=Deutschland">important message</a> for visitors outside Deutschland')
    end

    it "should default to no message if the country_from_ip domain doesn't exist" do
      allow(AlaveteliConfiguration).to receive(:gaze_url).and_return('http://12123sdf14qsd.com')
      get :other_country_message
      expect(response).to be_success
      expect(response.body).to eq('')
    end


    it "should default to no message if the country_from_ip service doesn't exist" do
      allow(AlaveteliConfiguration).to receive(:gaze_url).and_return('http://www.google.com')
      get :other_country_message
      expect(response).to be_success
      expect(response.body).to eq('')
    end

    it "should default to no message and log the error with url if the country_from_ip service returns an error" do       config = MySociety::Config.load_default()
      FakeWeb.register_uri(:get, %r|500.com|, :body => "Error", :status => ["500", "Error"])
      allow(AlaveteliConfiguration).to receive(:gaze_url).and_return('http://500.com')
      expect(Rails.logger).to receive(:warn).with /500\.com.*500 Error/
      get :other_country_message
      expect(response).to be_success
      expect(response.body).to eq('')
    end

  end

end
