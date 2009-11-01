$:.<<(File.dirname(__FILE__) + "/../")
require 'rubygems'
require 'sinatra'
require 'red-is'
require 'test/unit'
require 'rack/test'
require 'shoulda'
require 'active_support'
require 'active_support/testing/assertions'

set :environment, :test
set :views, (File.dirname(__FILE__) + "/../views")

class RedisTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include ActiveSupport::Testing::Assertions

  def app
    Sinatra::Application
  end
  
  context "When red.is'ing urls" do
    setup do
      $redis = Redis.new(:db => 10)
      $redis.flush_db
    end
    
    context 'on the index page' do
      should 'render the form' do
        get '/'
        assert last_response.body.include?('<form')
      end
      
      should "not include a red.is'd url" do
        get '/'
        assert !last_response.body.include?("red.is'd")
      end
    end
    
    context 'when creating a url' do
      should "include the notification that the url has been red.is'd" do
        post '/', {:url => "http://www.heise.de"}, {"HTTP_HOST" => 'localhost'}
        assert last_response.ok?
        url = RedisUrl.find_by_url("http://www.heise.de")
        assert last_response.body.include?("http://www.heise.de red.is'd to")
        assert last_response.body.include?("http://localhost/#{url.id}")
      end
      
      should "create the url in redis" do
        post '/', {:url => "http://www.heise.de"}, {"HTTP_HOST" => 'localhost'}
        assert_not_nil RedisUrl.find_by_url("http://www.heise.de")
      end
      
      should 'not create different shortened urls for the same url' do
        url = RedisUrl.create("http://www.heise.de")
        assert_no_difference 'RedisUrl.count' do
          post '/', :url => 'http://www.heise.de'
        end
      end
      
      context 'with plain text response' do
        should 'return only the generate short url' do
          post '/t', {:url => "http://www.heise.de"}, {"HTTP_HOST" => 'localhost'}
          url = RedisUrl.find_by_url('http://www.heise.de')
          assert_equal "http://localhost/#{url.id}", last_response.body
        end
      end
    end
    
    context 'when requesting a shortened url' do
      should 'redirect to the url' do
        url = RedisUrl.create("http://www.heise.de")
        get "/#{url.id}"
        assert last_response.redirect?
        assert_equal "http://www.heise.de", last_response.location
      end
      
      should 'display an error when the url couldnt be found' do
        get '/asdfas'
        assert last_response.not_found?
        assert last_response.body.include?("The specified key didn't do anything for me. Sorry.")
      end
    end
    
    context 'when requesting the details page for a shortened url' do
      should 'include the number of clicks' do
        url = RedisUrl.create("http://www.heise.de")
        10.times {url.clicked}
        get "/p/#{url.id}", {}, {"HTTP_HOST" => 'localhost'}
        assert last_response.body.include?('http://www.heise.de')
        assert last_response.body.include?("http://localhost/#{url.id}")
        assert last_response.body.include?("10 clicks")
      end
      
      should 'display an error when the url couldnt be found' do
        get '/p/asdfas'
        assert last_response.not_found?
        assert last_response.body.include?("The specified key didn't do anything for me. Sorry.")
      end
    end
  end
end