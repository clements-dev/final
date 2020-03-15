# Set up for the application and database. DO NOT CHANGE. #############################
require "sinatra"                                                                     #
require "sinatra/reloader" if development?                                            #
require "sequel"                                                                      #
require "logger"                                                                      #
require "twilio-ruby"                                                                 #
require "bcrypt"                                                                      #
require "geocoder"                                                                    #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB ||= Sequel.connect(connection_string)                                              #
DB.loggers << Logger.new($stdout) unless DB.loggers.size > 0                          #
def view(template); erb template.to_sym; end                                          #
use Rack::Session::Cookie, key: 'rack.session', path: '/', secret: 'secret'           #
before { puts; puts "--------------- NEW REQUEST ---------------"; puts }             #
after { puts; }                                                                       #
#######################################################################################

# put your API credentials here (found on your Twilio dashboard)
account_sid = ENV["TWILIO_ACCOUNT_SID"]
auth_token = ENV["TWILIO_AUTH_TOKEN"]

client = Twilio::REST::Client.new(account_sid, auth_token)

events_table = DB.from(:events)
rsvps_table = DB.from(:rsvps)
users_table = DB.from(:users)

before do
    @current_user = users_table.where(id: session["user_id"]).to_a[0]
end

# Main page
get "/" do
    @events_request = events_table.where(event_type: "request").all.to_a
    @events_coaching = events_table.where(event_type: "coaching").all.to_a
    view "events"
end

# First step of event creation
get "/events/new-1" do
    view "new_event1"
end

# Second step of event creation
get "/events/new-2" do
    # Find the location coordinates
    results = Geocoder.search(params["set_location"])
    
    unless results.first.nil?
        # Get location coordinates
        location_coord = results.first.coordinates # => [lat, long]
        @country_code = results.first.country_code
        city = results.first.city
        country = results.first.country
        if city==""
            @location_txt = country
        else
            #@location_txt = country + "&emsp;|&emsp;" + city
            @location_txt = city
        end
        @location_lat = location_coord[0]
        @location_lon = location_coord[1]

        # Open second step page
        view "new_event2"
    else
        view "new_event_failed.erb"
    end
end

# Create event in database
post "/events/create" do
    @event = events_table.where(id: params["id"]).to_a[0]
    @userp_name = users_table.where(id: session["user_id"]).to_a[1]
    
    if params["event_type"]=="DIY support request"
        event_t = "request"
    else
        event_t = "coaching"
    end

    events_table.insert(user_id: session["user_id"],
                        event_type: event_t,
                        title: params["title"],
                        description: params["description"],
                        date:  params["month"] + " " + params["day"] + ", " + params["year"],
                        location: params["location"],
                        lat: params["lat"],
                        lon: params["lon"])

    view "create_event"
end

get "/events/:id" do
    @event = events_table.where(id: params[:id]).to_a[0]
    @rsvps = rsvps_table.where(event_id: @event[:id])
    @attending_count = rsvps_table.where(event_id: @event[:id], attending: true).count
    @users_table = users_table
    view "event"
end

get "/events/:id/rsvps/new" do
    @event = events_table.where(id: params[:id]).to_a[0]
    view "new_rsvp"
end

# Create rsvp in database
get "/events/:id/rsvps/create" do
    @event = events_table.where(id: params["id"]).to_a[0]
    @userp_name = users_table.where(id: session["user_id"]).to_a[1]
    rsvps_table.insert(event_id: params["id"],
                       user_id: session["user_id"],
                       name: @userp_name,
                       attending: params["attending"],
                       comments: params["comments"])
    view "create_rsvp"
end

# First step of user creation
get "/users/new-1" do
    # Open first step sign up
    view "new_user1"
end

# Second step of user creation
get "/users/new-2" do
    # Find the location coordinates
    results = Geocoder.search(params["set_location"])
    
    unless results.first.nil?
        # Get location coordinates
        location_coord = results.first.coordinates # => [lat, long]
        @country_code = results.first.country_code
        city = results.first.city
        country = results.first.country
        if city==""
            @location_txt = country
        else
            #@location_txt = country + "&emsp;|&emsp;" + city
            @location_txt = city
        end
        @location_lat = location_coord[0]
        @location_lon = location_coord[1]

        #Open second step page
        view "new_user2"
    else
        view "new_event_failed.erb"
    end
end

# Create user in database
post "/users/create" do
    hashed_password = BCrypt::Password.create(params["password"])
    users_table.insert(name: params["name"], 
                        email: params["email"], 
                        phone: params["phone"], 
                        password: hashed_password, 
                        location: params["location"], 
                        lat: params["lat"], 
                        lon: params["lon"])
    @signup_user = params["name"]

    # Send text message
    begin
        client.messages.create(
            from: "+18479122565",
            to: params["phone"],
            body: "Welcome " + params["name"] + " to the DIY Platform!"
            )
    rescue
        puts "error while sending text message"    
    end

    view "create_user"
end

get "/logins/new" do
    view "new_login"
end

# Check and sign in if user credentials are right
post "/logins/create" do
    user = users_table.where(email: params["email"]).to_a[0]
    if user && BCrypt::Password::new(user[:password]) == params["password"]
        session["user_id"] = user[:id]
        @current_user = user
        view "create_login"
    else
        view "create_login_failed"
    end
end

# Logout
get "/logout" do
    session["user_id"] = nil
    @current_user = nil
    view "logout"
end