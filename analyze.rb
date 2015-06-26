def spo2_drops(session, spo2_thresh, time_thresh)

  buffer = [] # temporary buffer to store readings
  h = session.readings.order(:published_at).inject({}) do |r,i|
    
    if i.spo2 <= spo2_thresh
      # add reading to buffer
      buffer << i
      
    elsif buffer.any?
      # computer duration
      duration = i.published_at - buffer.first.published_at
      
      # if there are readings in the buffer, add them to the output hash
      if duration >= time_thresh
        r[duration] = [] unless r.has_key?(duration)
        r[duration] << buffer
      end
      
      # reset buffer array
      buffer = []
    end

    r # return residual
  end
  
  h # return h
end