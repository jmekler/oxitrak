class AddSessionIdToReadings < ActiveRecord::Migration
  def up
    # add session_id
    say_with_time "Adding session_id column to readings" do
      add_reference :readings, :session 
      Reading.reset_column_information
    end
    
    # assign session blocks
    say_with_time "Assigning readings to sessions" do
      Device.all.each do |d|      
        # get full list of readings
        readings = Reading.where(:device_id => d.id)
        
        # create initial session
        s = Session.create(:device_id => d.id, :active => false, :started_at => readings.first.published_at)        
        
        # interate through each reading to assign it to a session
        readings.each_with_index do |r,i|
          # end this session and make a new one if 10 minutes have passed between readings
          if (r.published_at - readings[[0, i-1].max].published_at) > 600
            # finalize the session
            s.update(:ended_at => readings[i-1].published_at)
            # create a new session
            s = Session.create(:device_id => d.id, :active => false, :started_at => r.published_at)
          end
          # update reading
          r.update(:session_id => s.id)
        end
        
      end
    end
    
    # remove device_id
    say_with_time "Removing device_id from readings" do 
      remove_reference :readings, :device
    end
  end
  
  def down
    # add device_id back to readings
    add_reference :readings, :device
    Reading.reset_column_information
    
    # assign device_id for each reading based on session
    Session.includes([:readings, :device]).each do |s|
      Reading.where(:session_id => s.id).update(:device_id => s.device.id)
    end

    # remove session_id back to readings    
    remove_reference :readings, :session
  end
end
