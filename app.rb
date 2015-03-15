require "sinatra/base"
require "sinatra/activerecord"

# EXPORT ENVIRONMENTAL VARS IN .env USING: export $(cat .env | xargs)     

class App < Sinatra::Base
  # extensions
  register Sinatra::ActiveRecordExtension
  
  # database configuration
  configure :development do
   set :database, {adapter: "sqlite3", database: "db/db.sqlite3"}
   set :show_exceptions, true
  end
  
  configure :production do
   db = URI.parse(ENV['DATABASE_URL'] || 'postgres:///localhost/mydb')
  
   ActiveRecord::Base.establish_connection(
     :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
     :host     => db.host,
     :username => db.user,
     :password => db.password,
     :database => db.path[1..-1],
     :encoding => 'utf8'
   )
  end
  
  # routes
  get "/" do
    "Hello World"
  end
  
  post "/api/spark", provides: :json do
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