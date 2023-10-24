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
    return data.to_json
  else
    puts "api request failed with status code: #{response.code}"
    puts "Response.body: #{response.body}"
    return nil
  end
end

def get_all_campuses(api_token)
  get_data(api_token, 'visualrf_api/v1/campus')
end

def get_campus(api_token, campus_id)
  get_data(api_token, "visualrf_api/v1/campus/#{campus_id}")
end

def get_building(api_token, building_id)
  get_data(api_token, "visualrf_api/v1/building/#{building_id}")
end

def get_floor(api_token, floor_id)
  get_data(api_token, "visualrf_api/v1/floor/#{floor_id}")
end

def get_access_points(api_token, floor_id)
  get_data(api_token, "visualrf_api/v1/floor/#{floor_id}/access_point_location")
end

def get_access_point_location(api_token, ap_id)
  get_data(api_token, "visualrf_api/v1/access_point_location/#{ap_id}")
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

#if we there is just 1 fixed floor, we can use this.
#def get_location_ap_in_floor(api_token, floor_id)
#  access_points = get_access_points(api_token, floor_id)
#  access_points['access_points'].each do |ap|
#    ap_id = access_point['ap_id']
#    access_point_location = JSON.parse(get_access_point_location(api_token, ap_id)
#    produce_to_kafka(access_point_location, @producer)
#  end
#end

#if there might be floors/buildings added in the future
def get_all_access_points_in_campus(api_token, campus_id)
  campus_data = JSON.parse(get_campus(api_token, campus_id))
  buildings = campus_data['buildings']
  all_data = []

  buildings.each do |building|
    building_id = building['building_id']
    floors = JSON.parse(get_building(api_token, building_id))['floors']
    if floors.nil?
      next
    end

    floors.each do |floor|
      floor_id = floor['floor_id']
      access_points = JSON.parse(get_access_points(api_token, floor_id))
      access_points['access_points'].each do |access_point|
        ap_id = access_point['ap_id']
        access_point_location = JSON.parse(get_access_point_location(api_token, ap_id))
        puts access_point_location
      end
    end
  end
  return all_data.to_json
end 

api_token = 'cmu0zwI2Mpd0DQkZpAeXH9SSbAobbcUD'

get_all_access_points_in_campus(api_token, '2797a84e69ab11ed977ed6dd37c16971__default')


