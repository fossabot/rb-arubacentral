#!/usr/bin/env ruby

require 'net/https'
require 'json'
require 'uri'

$aps_info = {}

def make_api_request(token, api_endpoint)
  uri = URI.join(API_BASE_URL, api_endpoint)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  request = Net::HTTP::Get.new(uri.request_uri)
  request['Authorization'] = "Bearer #{token}"
  request['Content-Type'] = 'application/json'
  http.request(request)
end

def get_data(token, api_endpoint)
  response = make_api_request(token, api_endpoint)
  if response.is_a?(Net::HTTPSuccess)
    data = JSON.parse(response.body)
    data
  else
    puts "api request failed with status code: #{response.code}"
    puts "Response.body: #{response.body}"
    {}
  end
end

def get_all_campuses(token)
    get_data(token, '/visualrf_api/v1/campus')
end

def get_campus(token, campus_id)
    get_data(token, '/visualrf_api/v1/campus/'+campus_id )
end

def get_building(token, building_id)
      get_data(token, '/visualrf_api/v1/building/'+building_id)
end

def get_aps(token, floor_id)
      get_data(token, '/visualrf_api/v1/floor/'+floor_id+'/access_point_location')
end

def get_wireless_clients(token)
  clients = get_data(token, "/monitoring/v1/clients/wireless")
  clients
end

def get_client_location(token, mac)
  location = get_data(token, '/visualrf_api/v1/client_location/'+mac)
  location
end

def get_ap_top(token)
  campuses=get_all_campuses(token)
  campuses["campus"].each do |campus|
    campus_info=get_campus(token, campus["campus_id"])
    buildings=campus_info["buildings"]
    buildings.each do |building|
      building_info=get_building(token, building["building_id"])
      floors=building_info["floors"]
      floors.each do |floor|
        aps=get_aps(token, floor["floor_id"])
        aps["access_points"].each do |ap|
          ap_info={}
          ap_info["floor"]=floor["floor_name"]
          puts "floor_id: #{floor["floor_id"]}"
          ap_info["building"]=building["building_name"]
          ap_info["campus"]=campus["campus_name"]
          ap_info["name"]=ap["ap_name"]
          # check if mac key do not exist before adding
          $aps_info[ap["ap_eth_mac"].downcase]=ap_info
        end
      end
    end 
  end
end

def move_coordinates_meters(lat, long, east_movement, north_movement)
  #lat: original latitude (degrees)
  #long: original longitude (degrees)
  #east_movement: distance moved to the east, negative for west movement (meters)
  #north_movement: distance moved to the north, negative for south movement (meters)
  earth_major_radius = 6378137.0
  earth_minor_radius = 6356752.3
  radians_to_degrees = 180 / Math::PI
  change_lat = north_movement / earth_minor_radius * radians_to_degrees
  change_long = east_movement / (earth_major_radius * Math.cos(lat / radians_to_degrees)) * radians_to_degrees
  new_lat = lat + change_lat
  new_long = long + change_long
  return new_lat, new_long
end

clients=get_wireless_clients(token) #gets a list of the clients connected to access points

unique_ad_macs = clients['clients'].map {|client| client['associated_device_mac']}.uniq
unique_ad_macs.each do |ad_mac|
  if $aps_info.key?(ad_mac)
    puts "true #{$aps_info} : #{ad_mac}"
  else
    puts "false #{$aps_info} : #{ad_mac}"
    get_ap_top(token)
  end
end

def get_hierarchy_string()
  clients["clients"].each do |client|
    "device with mac #{client["macaddr"]} is connected to #{aps_info[client["associated_device_mac"].downcase]["name"]} on #{aps_info[client["associated_device_mac"].downcase]["campus"]}>#{aps_info[client["associated_device_mac"].downcase]["building"]}>#{aps_info[client["associated_device_mac"].downcase]["floor"]}"
  end
end

#hierarchy = get_hierarchy_string
#lattitude, longitude = move_coordinates_meters()

to_produce = '{
    "StreamingNotification": {
      "subscriptionName": "%{sensor_name}",
      "entity": "%{entity}",
      "deviceId": "%{deviceId}",
      "mseUdi": "%{mseUdi}",
      "floorRefId": "%{floorRefId}",
      "location": {
        "macAddress": "%{macAddress}",
        "mapInfo": {
          "mapHierarchyString": "%{apHierarchy}",
          "floorRefId": "%{floorRefId}",
          "floorDimension": {
            "length": "%{length}",
            "width": "%{width}",
            "height": "%{height}",
            "offsetX": "%{offsetX}",
            "offsetY": "%{offsetY}",
            "unit": "%{unit}"
          },
          "image": {
            "imagename": "%{imagename}"
          }
        },
        "mapCoordinate": {
          "x": "%{x}",
          "y": "%{y}",
          "unit": "%{unit}"
        },
        "currentlyTracked": "%{currentlyTracked}",
        "confidenceFactor": "%{errorLevel}",
        "statistics": {
          "currentServerTime": "%{currentServerTime}",
          "firstLocatedTime": "%{firstLocatedTime}",
          "lastLocatedTime": "%{lastLocatedTime}"
        },
        "geoCoordinate": {
          "lattitude": %{lattitude},
          "longitude": %{longitude}
        },
        "ipAddress": "%{ipAddress}",
        "ssId": "%{ssId}",
        "band": "%{band}",
        "apMacAddress": "%{apMacAddress}",
        "dot11Status": "%{dot11Status}",
        "guestuser": "%{guestUser}"
      },
      "timestamp": "%{the_time}"
    }
  }' % {sensor_name: "WLC", entity: clients['client']['client_type'], deviceId: clients['client']['macaddr'],
        macAddress: clients['client']['macaddr'], 
        apHierarchy: hierarchy, lattitude: lattitude,
        longitude: longitude, apMacAddress: _apMacAddress.downcase,
        dot11Status: dot11Status, the_time: the_time}
