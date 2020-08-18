using Toybox.WatchUi;
using Toybox.Graphics;

class SimpleKalmanFilter {
	hidden var err_measure = 0.0;	//error of the measure
	hidden var err_estimate = 0.0;	//error of the estimation. Updated in real time
	hidden var qo = 0.0;			//Maximum Process noise
	hidden var q = 0.0;				//Process noise
	hidden var current_estimate = 0.0;
	hidden var last_estimate = 0.0;
	hidden var kalman_gain = 0.0;

	function initialize(mea_e, est_e, _qo) {
		err_measure = mea_e;
		err_estimate = est_e;
		qo = _qo;
		q = _qo;
	}

	function updateEstimate(mea) {
		kalman_gain = err_estimate / (err_estimate + err_measure);
		current_estimate = last_estimate + kalman_gain * (mea - last_estimate);
		err_estimate = (1.0 - kalman_gain) * err_estimate + abs(last_estimate - current_estimate) * q;
		updateProcessNoise();
		last_estimate = current_estimate;
		return current_estimate;
	}

	function setInitialState(initial) {last_estimate = initial;}

	function getLastEstimate() {return last_estimate;}

	function updateProcessNoise() {
		//Modify q according to process variation
		//Make q=qo for a constant process noise
		
		var a = abs(last_estimate - current_estimate);
		q = qo / (1 + a * a);
	}

	function abs(value) {
		if(value < 0) {value = -value;}
		return (value);
	}

}


class MapDataView extends WatchUi.DataField {
    hidden var dist_to_dest;
    hidden var heart_rate;
    hidden var speed;
    hidden var grade = 0;
    hidden var time_ahead;

    hidden var label_array = ["dist_to_dest", "hr", "speed", "grade", "time_ahead"];
    hidden var large_label_array = ["dist_to_dest", "time_ahead"];
    hidden var tiny_label_array = ["hr", "speed", "grade"];
    
    // Variables to store 'measured' altitude and elapsedDistance
	hidden var altitude = 0;
	hidden var elapsedDistance = 0;
	hidden var lastElapsedDistance = 0;
	
	// Variables to store 'filtered' altitude and elapsedDistance
	hidden var altitudeKalmanFilter;
	hidden var distanceKalmanFilter;
	
	// Variables to store gradient (and VAM)
	// hidden var grade = 0;
	hidden var vam;
    
    
    function initialize() {
        DataField.initialize();

		altitudeKalmanFilter = new SimpleKalmanFilter(2.5, 0.50, 0.10);
		distanceKalmanFilter = new SimpleKalmanFilter(1.0, 0.10, 0.05);
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc) {
        View.setLayout(Rez.Layouts.MainLayout(dc));
        for (var i = 0; i < large_label_array.size(); i++) {
        	var labelView = View.findDrawableById("label_" + large_label_array[i]);
	        labelView.locY = labelView.locY - 16;
	        var valueView = View.findDrawableById("value_" + large_label_array[i]);
	        valueView.locY = valueView.locY + 8;
        }
        
        for (var i = 0; i < tiny_label_array.size(); i++) {
        	var delta = 3;
        	var labelView = View.findDrawableById("label_" + tiny_label_array[i]);
	        //labelView.locY = labelView.locY - 18;
	        labelView.locY = labelView.locY - (1 - i) * 16 - delta;
	        labelView.locX = 80;
	        
	        var valueView = View.findDrawableById("value_" + tiny_label_array[i]);
	        valueView.locX = labelView.locX + 6;
	        valueView.locY = valueView.locY - (1 - i) * 16 - delta;
	        
        }

        View.findDrawableById("label_dist_to_dest").setText(Rez.Strings.label_dist_to_dest);
        View.findDrawableById("label_hr").setText(Rez.Strings.label_hr);
        View.findDrawableById("label_speed").setText(Rez.Strings.label_speed);
        View.findDrawableById("label_grade").setText(Rez.Strings.label_grade);
        View.findDrawableById("label_time_ahead").setText(Rez.Strings.label_time_ahead);
        return true;
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info) {
        // See Activity.Info in the documentation for available information.
        if(info has :currentHeartRate){
            if(info.currentHeartRate != null){
                heart_rate = info.currentHeartRate;
            } else {
                heart_rate = 0.0f;
            }
        }
        
        if(info has :distanceToDestination){
            if(info.distanceToDestination != null){
                dist_to_dest = info.distanceToDestination;
            } else {
                dist_to_dest = 0.0f;
            }
        }
        
        if(info has :currentSpeed){
            if(info.currentSpeed != null){
                speed = info.currentSpeed;
            } else {
                speed = 0.0f;
            }
        }
        
        //calc grade and vam
        altitude = info.altitude;
		// Active Timer Values
		if (info.timerState == Activity.TIMER_STATE_ON) {
		    elapsedDistance = (info.elapsedDistance != null) ? (info.elapsedDistance) : (0);
			// Calculate smooth Gradient and VAM, applying Simple Kalman Filter
			if (elapsedDistance != 0) {
	    		var lastAltitude = altitudeKalmanFilter.getLastEstimate();
	    		var lastDistance = distanceKalmanFilter.getLastEstimate();
	    		var currentAltitude = altitudeKalmanFilter.updateEstimate(altitude);
				var currentDistance = distanceKalmanFilter.updateEstimate(elapsedDistance - lastElapsedDistance);
				System.println(currentAltitude + " " + currentDistance);
				
				grade = (currentAltitude - lastAltitude) / currentDistance * 100;
				vam = ((currentAltitude - lastAltitude) * 3600).toNumber();
			}
			lastElapsedDistance = elapsedDistance;
		}

    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
        // Set the background color
        View.findDrawableById("Background").setColor(getBackgroundColor());

        // Set the foreground color and value
        // ["dist_to_dest", "hr", "speed", "grade", "time_ahead"]
        var dist_to_dest_value = View.findDrawableById("value_dist_to_dest");
        var d2d_txt = "";
        if (dist_to_dest < 1000){
        	d2d_txt = dist_to_dest.format("%d") + "m";
        } else {
        	d2d_txt = (dist_to_dest / 1000).format("%.1f") + "km";
        }
        dist_to_dest_value.setText(d2d_txt);
        
        var hr_value = View.findDrawableById("value_hr");
        hr_value.setText(heart_rate.format("%d"));
        
        var speed_value = View.findDrawableById("value_speed");
        speed_value.setText(speed.format("%.1f") + " kph");
        
        // var time_ahead_value = View.findDrawableById("value_time_ahead");
        // time_ahead_value.setText(time_ahead);
        
        var grade_value = View.findDrawableById("value_grade");
        grade_value.setText(grade.format("%d") + "%");
        
		
        for (var i = 0; i < label_array.size(); i++) {
        	var value = View.findDrawableById("value_" + label_array[i]);
		    if (getBackgroundColor() == Graphics.COLOR_BLACK) {
	            value.setColor(Graphics.COLOR_WHITE);
	        } else {
	            value.setColor(Graphics.COLOR_BLACK);
	        }
	    }
        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);
    }

}
