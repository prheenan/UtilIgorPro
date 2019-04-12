// Use modern global access method, strict compilation
#pragma rtGlobals=3	

#pragma ModuleName = ModVibrometer
#include ":::Util:IoUtil"
#include ":::Util:ErrorUtil"
#include "::asylum_interface"

Static Function assert_crosspoint_OK()
	String crosspoint_name = ModAsylumInterface#crosspoint_panel()
	ModAsylumInterface#assert_crosspoint_exists()
	ControlInfo /W=$(crosspoint_name) InAPopup
	ModErrorUtil#assert(ModIoUtil#strings_equal(S_Value,"BNCIn0"),msg="Must Set InA on ARC to BNCIn0")	
	ControlInfo /W=$(crosspoint_name) InBPopup
	ModErrorUtil#assert(ModIoUtil#strings_equal(S_Value,"BNCIn1"),msg="Must Set InB on ARC to BNCIn1")	
	ControlInfo /W=$(crosspoint_name) InFastPopup
	ModErrorUtil#assert(ModIoUtil#strings_equal(S_Value,"BNCIn2"),msg="Must Set InFast on ARC to BNCIn2")	
End Function

Static Function /S wave_name_x()
	return "prh_vibrometer_x"
End Function

Static Function /S wave_name_y()
	return "prh_vibrometer_y"
End Function

Static Function /S wave_name_z()
	return "prh_vibrometer_z"
End Function

Static Function setup_waves(n_points,decimation)
	Variable n_points , decimation
	Make /O/N=(n_points) $(wave_name_x()),$(wave_name_y()),$(wave_name_z())
	Wave wave_x = $(wave_name_x())
	Wave wave_y = $(wave_name_y())
	Wave wave_z = $(wave_name_z())
	// Set up all the waves, make sure they 
	ModErrorUtil#assert( (td_xsetinwave(0,"1","arc.input.Fast",wave_z,"",decimation) == 0))
	ModErrorUtil#assert( (td_xsetinwave(1,"1","arc.input.A",wave_x,"",decimation) == 0))
	ModErrorUtil#assert( (td_xsetinwave(2,"1","arc.input.B",wave_y,"",decimation) == 0))
End Function

Static Function Main([length_s,decimation,n_repeats])
	Variable length_s, decimation, n_repeats 
	length_s = ParamIsDefault(length_s) ? 3 : length_s
	decimation = ParamIsDefault(decimation) ? 10 : decimation
	n_repeats = ParamIsDefault(n_repeats) ? 1 : n_repeats
	String output_folder
	// Get a folder to output to
	//ModIoUtil#GetFolderInteractive(output_folder)
	// MAke sure the crosspoint exists and is set up correctly
	assert_crosspoint_OK()
	// POST: at least the cross point is set up correctly.
	// Set up all the waves
	Variable f_raw_Hz = 50e3
	Variable f_decimated_Hz = f_raw_Hz/decimation
	Variable n_points = length_s * f_decimated_Hz
	setup_waves(n_points,decimation)
	// Call the event
	ModErrorUtil#assert( (td_ws("event.1","once") == 0) )
End Function