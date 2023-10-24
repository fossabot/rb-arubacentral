#!/usr/bin/env ruby

#very similar is /opt/rb/var/rb-ale/bin/rb_ale.rb

require 'net/https'
require 'json'
require 'uri'
require 'set'
#require 'poseidon'

API_BASE_URL = 'https://apigw-eucentral3.central.arubanetworks.com/'

def make_api_request(api_token, api_endpoint)
  uri = URI.join(API_BASE_URL, api_endpoint)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')

  request = Net::HTTP::Get.new(uri.request_uri)
  request['Authorization'] = "Bearer #{api_token}"
  request['Content-Type'] = 'application/json'

  http.request(request)
end

def get_data(api_token, api_endpoint)
  response = make_api_request(api_token, api_endpoint)
  
  if response.code.to_i == 200
    data = JSON.parse(response.body)
    return data
  else
    puts "api request failed with status code: #{response.code}"
    puts "Response.body: #{response.body}"
    return nil
  end
end

#topic is not created yet
def produce_to_kafka(msg, topic='rb_arubacentral')
  begin
    messages = []
    messages << Poseidon::MessageToSend.new(topic, msg)
    @producer.send_messages(messages)
  rescue => e
    p "Error producing messages to kafka #{topic}: #{e.message}"
  end
end

#if there might be floors/buildings added in the future
def get_all_access_points_in_campus(api_token)
  campuses = get_data(api_token, "visualrf_api/v1/campus")
 
  campuses['campus'].each do |campus|
    campus_id = campus['campus_id']
    campus_data = get_data(api_token, "visualrf_api/v1/campus/#{campus_id}")
    #buildings = campus_data['buildings']

    #buildings.each do |building|
    campus_data['buildings'].each do |building|
      building_id = building['building_id']
      building_data = get_data(api_token, "visualrf_api/v1/building/#{building_id}")
      #floors = building_data['floors']

      #floors.each do |floor|
      building_data['floors'].each do |floor|
        floor_id = floor['floor_id']
        access_points = get_data(api_token, "visualrf_api/v1/floor/#{floor_id}/access_point_location")
     
        access_points['access_points'].each do |access_point|
          ap_id = access_point['ap_id']
          access_point_location = get_data(api_token, "visualrf_api/v1/access_point_location/#{ap_id}")
          puts access_point_location
        end
      end
    end
  end
end 

api_token = 'rJYnlw6FcGID6x6b0WGfBzrveMQe1AnI'

get_all_access_points_in_campus(api_token)

