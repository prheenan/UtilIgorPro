// Use modern global access method, strict compilation
#pragma rtGlobals=3	

#pragma ModuleName = ModVibrometer
#include ":::Util:PlotUtil"
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

Function prh_vibrometer_waves_to_csv() 
	// Sleep for a small fraction, to make sure other waves are done
	sleep /s 0.5
	// Get the current waves
	Wave wave_x = $(wave_name_x())
	Wave wave_y = $(wave_name_y())
	Wave wave_z = $(wave_name_z())
	// Save out the concatenated wave 
	Concatenate /O {wave_x, wave_y, wave_z}, prh_final
	String output_name
	SVAR GLOBAL_output_folder
	NVAR GLOBAL_output_n 
	sprintf output_name, "%sVibrometer%05d.csv", GLOBAL_output_folder,  GLOBAL_output_n
	Save/O/J/M="\r\n"/W/U={1,1,0,0} prh_final as (output_name)
	KillWaves /Z prh_final
	// Increment the output N 
	Variable /G GLOBAL_output_n = GLOBAL_output_n + 1
	NVAR GLOBAL_max_n
	if (GLOBAL_output_n < GLOBAL_max_n) 
		setup_and_run()
	endif
End Function

Static Function setup_waves()
	NVAR GLOBAL_n_points 
	NVAR GLOBAL_decimation
	// clear everything
	ModPlotUtil#clf(); 
	// Kill the waves
	KillWaves /Z prh_vibrometer_x , prh_vibrometer_y, prh_vibrometer_z ;
	Make /O/N=(GLOBAL_n_points) $(wave_name_x()),$(wave_name_y()),$(wave_name_z())
	Wave wave_x = $(wave_name_x())
	Wave wave_y = $(wave_name_y())
	Wave wave_z = $(wave_name_z())
	// Set up all the waves, make sure they 
	ModErrorUtil#assert( (td_xsetinwave(0,"1","arc.input.Fast",wave_z,"",GLOBAL_decimation) == 0))
	ModErrorUtil#assert( (td_xsetinwave(1,"1","arc.input.A",wave_x,"",GLOBAL_decimation) == 0))
	ModErrorUtil#assert( (td_xsetinwave(2,"1","arc.input.B",wave_y,"prh_vibrometer_waves_to_csv()",GLOBAL_decimation) == 0))
End Function

Static Function run_until_complete()
	ModErrorUtil#assert( (td_ws("event.1","once") == 0) )
End Function

Static Function setup_and_run()
	setup_waves()
	// Call the event
	run_until_complete()
End Function 

Static Function Main([length_s,decimation,n_repeats,delay_s])
	Variable length_s, decimation, n_repeats , delay_s
	length_s = ParamIsDefault(length_s) ? 3 : length_s
	decimation = ParamIsDefault(decimation) ? 10 : decimation
	n_repeats = ParamIsDefault(n_repeats) ? 2 : n_repeats
	delay_s = ParamIsDefault(delay_s) ? 0 :delay_s
	// Determine how long the waves should be
	Variable f_raw_Hz = 50e3
	Variable f_decimated_Hz = f_raw_Hz/decimation
	Variable n_points = length_s * f_decimated_Hz
	String output_tmp
	// Get a folder to output to
	ModIoUtil#GetFolderInteractive(output_tmp) 
	String /G GLOBAL_output_folder = output_tmp
	Variable /G GLOBAL_output_n = 0 
	Variable /G GLOBAL_max_n = n_repeats
	Variable /G  GLOBAL_n_points = n_points
	Variable /G GLOBAL_decimation = decimation
	// MAke sure the crosspoint exists and is set up correctly
	assert_crosspoint_OK()
	// Delay, if needed
	if (delay_s > 0)
		sleep /S delay_s
	endif
	// write the waves on the callback.
	// Note that this uses the global variable to correctly get the right number 
	setup_and_run()
End Function	

