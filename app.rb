require "sinatra/base"
require "sinatra/activerecord"
require "chartkick"
require "hashids"

# EXPORT ENVIRONMENTAL VARS IN .env USING: export $(cat .env | xargs)     

class RingBuffer < Array
  attr_reader :max_size
 
  def initialize(max_size, enum = nil)
    @max_size = max_size
    enum.each { |e| self << e } if enum
  end
 
  def <<(el)
    if self.size < @max_size || @max_size.nil?
      super
    else
      self.shift
      self.push(el)
    end
  end
 
  alias :push :<<
end

class Array
  # Calculates the moving average 
  # given a Integer as a increment period

  def moving_average(increment = 1)
    return self if increment == 1
    
    a = self.dup
    buff = RingBuffer.new(increment, a.slice!(0,increment))
    result = [buff.average]
    
    while (!a.empty?)
      buff << a.slice!(0)
      result << buff.average
    end
    
    result
  end
  
  def percentile(percentile)
    values_sorted = self.sort
    k = (percentile*(values_sorted.length-1)+1).floor - 1 
#     f = (percentile*(values_sorted.length-1)+1).modulo(1)

    return values_sorted[k]#  + (f * (values_sorted[k+1] - values_sorted[k]))
  end

  # Calculates the average
  def average
    (self.sum/self.size)
  end
end



class App < Sinatra::Base
  # extensions
  register Sinatra::ActiveRecordExtension
  
    
  configure :development do
#     enable :logging
#     set :database, {adapter: "sqlite3", database: "db/db.sqlite3"}
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
    if @device = Device.find_by_core_id(params[:id])      
      @sessions = @device.sessions.includes(:readings).order(started_at: :desc).limit(13)
      @active = @sessions.first
      
      @session_score = @sessions.map do |s|
        s.readings.map{|i| i.spo2}.moving_average(5).percentile(0.05)
      end
      
      erb :device
    end
  end
  
  get "/sessions/:id" do 
    if @active = Session.includes(:device).find( decode(params[:id]) )    
      endTime = 
      @sessions = @active.device.sessions.where("ended_at > ? AND ended_at < ?", @active.ended_at-5.days, @active.ended_at+5.days).order(ended_at: :desc)      
#       @sessions = [@active.previous, @active, @active.next]
      
      erb :session
    end
  end

  post "/api/spark-reading" do
    # merge json params with post params
	#     p params
	# 	p request.body.read
	# 	p ActiveSupport::JSON.decode(request.body.read)
	#     params.merge!(ActiveSupport::JSON.decode(request.body.read))   
    
    # validate device ID
    if @device = Device.find_by_core_id(params["coreid"])
		# try to find the latest session to append the reading to
		if @session = @device.sessions.includes(:readings).where(active: true).last 
			# expire old / invalid sessions
	        unless @session.readings.any? && ((Time.now - @session.readings.last.published_at) < 60*60)
		        @session.update(active: false, ended_at: @session.readings.last.published_at)
		        @session = nil
	        end
	    end
      
      # create a new session if necessary
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
#     
#     # find device and return hash of session_id
#     if @device = Device.includes(:sessions).find_by_core_id(params["core_id"])
#       # find the active session, a session that ended in the last 5 minutes, or create a new session
#       @session = @device.sessions.find_by(active: true) || @device.sessions.find_by("ended_at < ?", Time.now - 5.minutes) || @device.sessions.create(active: true, started_at: Time.now)
#       
#       # update the status of a previously ended session
#       @session.update(active: true, ended_at: nil) unless @session.active?
# 
#       # return format: "CORE_ID SESSION_HASH"      
#       return "#{params["core_id"]} #{encode(@session.id)}"
#     end
#     
#     return "#{params["core_id"]} f"
    return "oxi/sessions/create: #{params["core_id"]}"
  end
  
  # update a session (json or post params should include an action)
  post "/api/sessions/:id" do
      return "#{params["core_id"]}"
#     # merge json params with post params
#     params.merge!(ActiveSupport::JSON.decode(request.body.read))
#     
#     # get session object    
#     @session = Session.includes(:device).find( decode(params[:id]) )
#     
#     # update session
#     case params["action"]    
#       # end the session
#       when "end"
#         if @session and @session.active? and Session.update(@session.id, active: false, ended_at: Time.now)
#           return "t"
#         end
#     end
#     
#     # something went wrong
#     return "f"
    return "oxi/sessions/end: #{params["core_id"]}"
  end
  
  # create a new reading
  post "/api/sessions/:id/readings/" do 
    # # merge json params with post params
#     params.merge!(ActiveSupport::JSON.decode(request.body.read))
#     
#     # get session object
#     @session = Session.includes(:device).find( decode(params[:id]) )
#     
#     # check to ensure that session is valid, active, and corresponds to core_id
#     if @session and @session.active? and @session.device.core_id == @params["core_id"]
#     
#       # create the reading
#       if @session.readings.create(params["data"])
#         return "#{params["core_id"]} t"
#       end  
#     end
#     
#     # something went wrong
#     return "#{params["core_id"]} f"
    return "oxi/readings/create: #{params["core_id"]}"
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
  before_create :initialize_session
  belongs_to :device
  has_many :readings

  def next
    self.class.unscoped.where("started_at >= ? AND id != ?", started_at, id).order("started_at ASC").first
  end
  
  def previous
    self.class.unscoped.where("started_at <= ? AND id != ?", started_at, id).order("started_at DESC").first
  end
  
  private  
    def initialize_session
        self.started_at = Time.now.utc
        self.active = true
    end
end