# Set up for the application and database. DO NOT CHANGE. #############################
require "sequel"                                                                      #
require "bcrypt"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB = Sequel.connect(connection_string)                                                #
#######################################################################################

# Database schema - this should reflect your domain model
DB.create_table! :events do
  primary_key :id
  foreign_key :user_id
  String :event_type
  String :title
  String :description, text: true
  String :date
  String :location
  Double :lat
  Double :lon
end
DB.create_table! :rsvps do
  primary_key :id
  foreign_key :event_id
  foreign_key :user_id
  Boolean :attending
  String :name
  String :comments, text: true
end

DB.create_table! :users do
  primary_key :id
  String :name
  String :email
  String :password
  String :phone
  String :location
  Double :lat
  Double :lon
end

# Insert initial (seed) data
events_table = DB.from(:events)
users_table = DB.from(:users)

events_table.insert(title: "Final day - KIEI_451-0_SEC81", 
                    user_id: 0,
                    event_type: "coaching",
                    description: "End of course!",
                    date: "March 9, 2020",
                    location: "Chicago",
                    lat: 41.8831157,
                    lon: -87.6389398)

events_table.insert(title: "Final Project - KIEI_451-0_SEC81", 
                    user_id: 0,
                    event_type: "request",
                    description: "Last project!",
                    date: "March 15, 2020",
                    location: "Chicago",
                    lat: 41.8831157,
                    lon: -87.6389398)

cdb_hashed_password = BCrypt::Password.create("admin")
users_table.insert(name: "admin",
                    email: "admin",
                    password: cdb_hashed_password,
                    location: "Chicago",
                    lat: 0,
                    lon: 0)