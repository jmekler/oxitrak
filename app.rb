require "sinatra/base"
require "sinatra/activerecord"
require "chartkick"

# EXPORT ENVIRONMENTAL VARS IN .env USING: export $(cat .env | xargs)     

class App < Sinatra::Base
  # extensions
  register Sinatra::ActiveRecordExtension
  
  db = URI.parse(ENV['DATABASE_URL'] || 'postgres:///localhost/mydb')

  ActiveRecord::Base.establish_connection(
   :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
   :host     => db.host,
   :username => db.user,
   :password => db.password,
   :database => db.path[1..-1],
   :encoding => 'utf8'
 )
  
  # routes
  get "/" do
    "Hello World"
  end
  
  get "/:device" do
    if @device = Device.find_by_core_id(params[:device])
      @readings = @device.readings.where(published_at: (Time.now-1.day)..Time.now )
      @spo2 = @readings.map {|r| [r.published_at, r.min_spo2]}
      @hr = @readings.map {|r| [r.published_at, r.mean_hr]}
      @data = [{name: "SpO2", data: @spo2}, {name: "Heart Rate", data: @hr}]
      erb :device
    else
      redirect "/"
    end
  end
  
  post "/api/reading" do 
    params[:published_at] = Time.now;
    device = Device.find(1);
    if (@reading = device.readings.create(params))
      puts "Created: #{@reading}"
    else
      puts "Error creating reading with params:"
      puts params
    end
  end
  
  get "/api/spark" do
    
    @params = ActiveSupport::JSON.decode(request.body.read)
    
    # search for device
    if device = Device.find_by_core_id(@params["coreid"])
      # parse data
      keys = [:min_spo2, :mean_spo2, :mean_hr, :quality]
      data = Hash[keys.zip @params["data"].split(" ")]
      data[:published_at] = @params["published_at"]      
      if device.readings.create(data)
        puts device
      end
    end
  end
end

# activerecord models
class Device < ActiveRecord::Base
  # string :core_id
  # string :model
  has_many :readings
end

class Reading < ActiveRecord::Base
  # float :mean_hr
  # float :mean_spo2
  # float :min_spo2
  # float :quality
  # datetime published_at
  # reference device_id
  belongs_to :device
end