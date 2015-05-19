require "sinatra/base"
require "sinatra/activerecord"
require "chartkick"
require "hashids"

# EXPORT ENVIRONMENTAL VARS IN .env USING: export $(cat .env | xargs)     

class App < Sinatra::Base
  # extensions
  register Sinatra::ActiveRecordExtension
  
  configure :development do
    enable :logging
    set :database, {adapter: "sqlite3", database: "db/db.sqlite3"}
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
  
  # Hashids integration
  set :hashids, Hashids.new("emma", 8)  
  def encode(id)
    settings.hashids.encode(id)
  end  
  
  def decode(hash)
    ids = settings.hashids.decode(hash)
    (ids.length == 1) ? ids[0] : ids  
  end
  
  
  # routes
  get "/" do
    erb :index
  end
  
  get "/device/:id" do
    if @device = Device.includes(:sessions).find_by_core_id(params[:id])
      @sessions = @device.sessions
      erb :device
    end
  end
  
  get "/sessions/:id" do 
    if @session = Session.includes(:device).find( decode(params[:id]) )
      @readings = @session.readings.where("quality > 0.9")
      erb :session
    end
  end
  
#   post "/api/reading" do 
#     params[:published_at] = Time.now
#     @device = Device.find(1);
#     @session = @device.sessions.where(active: true) || @device.sessions.create
#     if (@reading = @session.readings.create(params))
#       puts "Created: #{@reading}"
#     else
#       puts "Error creating reading with params:"
#       puts params
#     end
#   end
#   

  post "/api/spark-reading" do
    # merge json params with post params
    params.merge!(ActiveSupport::JSON.decode(request.body.read))   
    if @device = Device.includes(:sessions).find_by_core_id(params["coreid"])
      if @session = @device.sessions.where(active: true).last 
        unless @session.readings.any? && ((Time.now - @session.readings.last.published_at) < 60*30)
          @session.update(active: false)
          @session = nil
        end
      end
      
      @session ||= @device.sessions.create
      
      # parse data
      keys = [:spo2, :hr, :quality]
      data = Hash[keys.zip @params["data"].split(" ")]
      data[:published_at] = @params["published_at"]      
      @session.readings.create(data)
    end
  end
  
  # create a session
  post "/api/sessions/" do
    # merge json params with post params
    params.merge!(ActiveSupport::JSON.decode(request.body.read))
    
    # find device and return hash of session_id
    if @device = Device.includes(:sessions).find_by_core_id(params["core_id"])
      # find the active session, a session that ended in the last 5 minutes, or create a new session
      @session = @device.sessions.find_by(active: true) || @device.sessions.find_by("ended_at < ?", Time.now - 5.minutes) || @device.sessions.create(active: true, started_at: Time.now)
      
      # update the status of a previously ended session
      @session.update(active: true, ended_at: nil) unless @session.active?

      # return format: "CORE_ID SESSION_HASH"      
      return "#{params["core_id"]} #{encode(@session.id)}"
    end
    
    return "#{params["core_id"]} f"
  end
  
  # update a session (json or post params should include an action)
  post "/api/sessions/:id" do
    # merge json params with post params
    params.merge!(ActiveSupport::JSON.decode(request.body.read))
    
    # get session object    
    @session = Session.includes(:device).find( decode(params[:id]) )
    
    # update session
    case params["action"]    
      # end the session
      when "end"
        if @session and @session.active? and Session.update(@session.id, active: false, ended_at: Time.now)
          return "t"
        end
    end
    
    # something went wrong
    return "f"
  end
  
  # create a new reading
  post "/api/sessions/:id/readings/" do 
    # merge json params with post params
    params.merge!(ActiveSupport::JSON.decode(request.body.read))
    
    # get session object
    @session = Session.includes(:device).find( decode(params[:id]) )
    
    # check to ensure that session is valid, active, and corresponds to core_id
    if @session and @session.active? and @session.device.core_id == @params["core_id"]
    
      # create the reading
      if @session.readings.create(params["data"])
        return "#{params["core_id"]} t"
      end  
    end
    
    # something went wrong
    return "#{params["core_id"]} f"
  end
end

### activerecord models ###
class Device < ActiveRecord::Base
  # string :core_id
  # string :model
  has_many :sessions
  
  # validations
  validates_uniqueness_of :core_id
end

class Reading < ActiveRecord::Base
  # float :hr
  # float :spo2
  # float :quality
  # datetime published_at
  # reference session_id
  belongs_to :session
end

class Session < ActiveRecord::Base  
  belongs_to :device
  has_many :readings
  
  def before_create
      started_at = Time.now
      active = true
  end
end