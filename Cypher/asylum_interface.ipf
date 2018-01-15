// Use modern global access method, strict compilation
#pragma rtGlobals=3	

#pragma ModuleName = ModAsylumInterface
#include "::Util:IoUtil"
#include ":ForceModifications"

Static Function /S force_review_graph_name()
	// Returns: the name of the graph Asylum uses for ForceReview stuff 
	return "ForceReviewGraph"
End Function

Static Function /S master_force_panel_name()
	// Returns: the name of the master force panel
	return "MasterForcePanel"
End Function

Static Function /S force_review_list_control_name()
	return "ForceList_0"
End Function

Static Function /WAVE master_variable_info()
	// Returns: the master panel variable wave
	return root:packages:MFP3D:Main:Variables:MasterVariablesWave
End Function

Static Function /S master_base_name()
	// Returns: the master panel base name
	SVAR str_v = root:packages:MFP3D:Main:Variables:BaseName
	// XXX check SVAR exists.
	return str_v
End Function

Static Function current_image_suffix()
	// Returns: the current image id or suffix (e.g. 1 for 0001)
	return master_variable_info()[%BaseSuffix][%Value]
End Function


Static Function /Wave get_force_review_wave(type,[return_x,suffix])
	// Gets the just-saved Wave, assuming it is displayed on the force review graph
	//
	// Args:
	//	type: the extension we want to use (e.g. 'ZSnsr_Ext')
	//	return_x: if true, return the *x* wave reference, instead of the y wave
	//	suffix: the suffix to look for. defaults to the last saved plot
	//
	// Returns: 
	//	reference to the last-saved wave (assuming it is plotted in the ForceReviewGraph)
	String type
	Variable return_x,suffix
	if (ParamIsDefault(suffix))
		suffix = ModAsylumInterface#current_image_suffix()-1
	endif
	String base_name = ModAsylumInterface#master_base_name()
	String trace_name = ModAsylumInterface#formatted_wave_name(base_name,suffix,type=type)
	// set the current graph to the force review panel
	String review_name = ModAsylumInterface#force_review_graph_name()	
	// get the note of DeflV on the force review graph
	if (return_x)
		Wave to_ret = ModPlotUtil#graph_wave_x(review_name,trace_name)
	else
		Wave to_ret = ModPlotUtil#graph_wave(review_name,trace_name)		
	endif
	return to_ret
End Function


Static Function /S update_note_resolution(original_note,freq,n)
	// updates a given note for a higher-resolution wave
	//
	// Args:
	//	original_note: the original source
	//	freq: the sampling frequency
	//	n: the new size of the wave
	// Returns:
	//	The updated note
	String original_note
	Variable freq,n
	String new_note
	new_note = ModAsylumInterface#replace_note_variable(original_note,"ForceFilterBW",freq/2)
	new_note = ModAsylumInterface#replace_note_variable(new_note,"NumPtsPerSec",freq)
	new_note = ModAsylumInterface#replace_note_variable(new_note,"MaxPtsPerSec",freq)
	new_note = ModAsylumInterface#replace_note_variable(new_note,"NumPtsPerWave",n)
	new_note = ModAsylumInterface#replace_note_variable(new_note,"TarPtsPerWave",n)
	return new_note
End Function


Static Function get_wave_suffix_number(wave_name)
	// Given a wave name, returns its suffix
	//
	// Args:
	//	wave_name: full name, formatted somethine like Image0010_DeflV
	// Returns;
	//	numeric suffix
	String wave_name
	String suffix_string = ""
	// pattern is: <start,anything non-greedy, four digits, possible non digits, end>
	String pattern = "^.*?([\d]{4})\D*$"
	Variable matched = ModIoUtil#set_and_return_if_match(wave_name,pattern,suffix_string)
	ModErrorUtil#Assert(matched,msg="Wave name should be formatted like <Non Digits>0123<Non digits>")
	Variable suffix = str2num(suffix_string)
	return suffix
End Function	


Static Function get_wave_crossing_index(wave_to_get,[epsilon_f])
	// Gets when the wave crosses Max-epsilon_f * range.
	// Useful for aligning two nominally identical curves at different resolution
	//
	// Args:
	//	wave_to_get: wave of interest
	//	epsilon_f: how much of the range should be used
	Wave wave_to_get
	Variable epsilon_f
	epsilon_f = ParamIsDefault(epsilon_f) ? 0.01 : epsilon_f
	// POST: parameters set up 
	Variable max_z = WaveMax(wave_to_get)
	Variable min_z = WaveMin(wave_to_get)
	Variable range_z = max_z-min_z
	// epsilon is defined in terms of the range...
	Variable level_to_cross = max_z - epsilon_f * abs(range_z)
	// return the first time we are above the level.
	return ModNumerical#first_index_greater(wave_to_get,level_to_cross)
End Function

Static Function /S get_indexes(note_v)
	String note_v
	return ModAsylumInterface#note_string(note_v,"Indexes")
End Function

Static Function get_index_field_element(indexes,number)
	String indexes
	Variable number
	String index_sep = ","
	return str2num(ModIoUtil#string_element(indexes,number,sep=index_sep))
End Function

Static Function /S update_note_triggering(low_res_note,low_res_z_wave,high_res_z_wave,freq_low,freq)
	// fix the indices for the high resolution wave; these will only be approximately correct, since 
	// there will probably be an offset. This is helpful for graphing everything (asylum splits by Indexes
	// in the force review panel)
	//
	// Args:
	//	low_res_note: the note we are updating
	//	low_res_z_wave: the original ZSnsr wave, should contain the approach and dwell
	//	high_res_z_wave: the new ZSnsr wave we want. should contain (at least) the approach and dwell
	//	freq_low/freq: the sampling frequencies of the low and high resolution waves
	// Returns;
	//	note with updated triggering times and indices
	String low_res_note
	Wave low_res_z_wave,high_res_z_wave
	Variable freq_low,freq
	String indices = get_indexes(low_res_note)
	// The order of the indices is <0,start of dwell, end of dwell, end of wave>
	Variable low_res_dwell_start =get_index_field_element(indices,1)
	Variable low_res_dwell_end = get_index_field_element(indices,2)
	// get the conversion from low to high res, just the ratio of the sampling frequencies
	Variable conversion = freq/freq_low
	// get the index of the max in the low and high resolution
	Variable idx_max_low_resolution = get_wave_crossing_index(low_res_z_wave)
	Variable idx_max_high_resolution = get_wave_crossing_index(high_res_z_wave)
	// convert the low resolution into what it *would* be, in high resolution points 
	Variable idx_effective_low_resolution = (idx_max_low_resolution * conversion)
	// when we add in the offset, the difference between the maxima should be zero. 
	Variable offset = ceil(idx_max_high_resolution-idx_effective_low_resolution)
	// determine the 'real' offset indices into the higher-resolution data
	Variable idx_start_dwell = ceil(low_res_dwell_start*conversion) + offset
	Variable idx_end_dwell = ceil(low_res_dwell_end*conversion) + offset
	Variable n = DimSize(high_res_z_wave,0)
	Variable end_point = n-1
	// fix the trigger point and dwell time (later code use these)
	Variable updated_trigger_time = pnt2x(high_res_z_wave,idx_start_dwell)
	Variable updated_dwell_time = pnt2x(high_res_z_wave,idx_end_dwell) - updated_trigger_time
	low_res_note = ModAsylumInterface#replace_note_variable(low_res_note,"TriggerTime",updated_trigger_time)
	low_res_note = ModAsylumInterface#replace_note_variable(low_res_note,"DwellTime",updated_dwell_time)	
	// replace the indices; they are just CSV
	String indexes_for_note 
	sprintf indexes_for_note, "%d,%d,%d,%d",offset,idx_start_dwell,idx_end_dwell,end_point
	low_res_note = ModAsylumInterface#replace_note_string(low_res_note,"Indexes",indexes_for_note)
	return low_res_note
End Function


Static Function /S formatted_wave_name(base,suffix,[type])
	// Formats a wave name as the cyper (e.g.  Image_0101Deflv)
	//
	// Args:
	//	base: name of the wave (e.g. 'Image')
	//	suffix: id of the wave (e.g. 1)
	//     type: optional type after the suffix (e.g. 'force')
	// Returns:
	//	Wave formatted as an asylum name would be, given the inputs
	String base,type
	Variable suffix
	String to_ret
	if (ParamIsDefault(type))
		type = ""
	EndIf
	// Formatted like <BaseName>_<justified number><type>
	// e.g. Image_0101Deflv
	sprintf to_ret,"%s%04d%s",base,suffix,type
	return to_ret
End Function

Static Function /S note_string(note_v,key_to_get)
	// Gets an asylum-style value from its key in a note
	
	// Args:
	//	See replace_note_variable
	// Returns:
	//	The value of sotred in the note of the key
	String note_v,key_to_get
	return StringByKey(key_to_get,note_v,":","\r")
End function

Static Function note_variable(note_v,key_to_get)
	// Returns a note variable as a number
	//
	// Args: 
	//	see   replace_note_variable
	// Returns
	//    The variable (numeric) representation of the note value at the given key
	String note_v,key_to_get
	return str2num(note_string(note_v,key_to_get))
End Function

Static Function /S replace_note_string(note_v,key_to_replace,new_string)
	// replaces an asylum-style string value associated with a key
	//
	// Args:
	//	see replace_note_variable
	// Returns
	//	updated note
	String note_v,key_to_replace,new_string
	return ReplaceStringbyKey(key_to_replace,note_v,new_string,":","\r")
End Function

Static Function /S replace_note_variable(note_v,key_to_replace,new_value)
	// replaces an asylum-style string variable
	// 
	// Args:
	//	note_v: the note to search in / replace
	//	key_to_replace: within the asylum-style note, the key we want to replace
	// 	new_value: the numeric value to put in (saved to 10 decimal places)
	// Returns:
	//	updated note 
	String note_v,key_to_replace
	Variable new_value
	String value_as_string
	sprintf value_as_string,"%.10g",new_value
	return replace_note_string(note_v,key_to_replace,value_as_string)
End Function

Static Function /S default_wave_base_name()
	// Returns: the default wave, according to the (global / cypher) Suffix and base
	Variable suffix =current_image_suffix()+1
	String base = master_base_name()
	return  formatted_wave_name(base,suffix)
End Function 

Static Function volts_to_meters(zsnsr_v,defl_v,z_lvdt_sensitivity,invols,z_meters,defl_meters)
	// Converts zsnsr and defl (both assumed in volts) to meters
	//
	// Args:
	//	<zsnsr/defl_v> : the z sensor and deflection channel in volts
	//	z_lvdt_sensitivity: the conversion from zstage volts to meters (m/V)
	//	invols: the conversion from deflection volts to meters (m/V)
	//	defl_meters: output wave in meters
	//	z_meters: output wave in meters
	// Returns:
	//	Nothing, but sets <defl/z>_meters appropriately
	Wave zsnsr_v,defl_v
	Variable z_lvdt_sensitivity,invols
	Wave defl_meters,z_meters
	// Convert the volts to meters for ZSnsr
	Duplicate /O zsnsr_v,z_meters
	Fastop z_meters=(z_lvdt_sensitivity)*zsnsr_v
	SetScale d -10, 10, "m", z_meters
  	// Convert the volts to meters for DeflV
	Duplicate /O defl_v,defl_meters
	fastop defl_meters= (invols)*defl_v
	SetScale d -10, 10, "m", defl_meters
End Function

Static Function note_invols(wave_note)
	// Args;
	//	wave_note: the asylum-style note want the sensitivity
	// Returns: 
	//	the inverse volts optical lever arm sensitivity (INVOLS)
	String wave_note
	return note_variable(wave_note,"Invols")
End Function

Static Function note_z_sensitivity(wave_note)
	// Args;
	//	wave_note: the asylum-style note want the sensitivity
	// Returns: 
	//	the Z Liner voltage differential transducer (ZLVDT) sensitivity
	String wave_note
	return note_variable(wave_note,"ZLVDTSens")
End Function

Static Function save_to_disk_volts(zsnsr_volts_wave,defl_volts_wave,[note_to_use])
	// Saves the given waves (all in volts) to disk (in meters)
	// Args:
	// 	See: save_to_disk
	// Returns: 
	//	nothing
	Wave zsnsr_volts_wave,defl_volts_wave
	String note_to_use
	if (ParamIsDefault(note_to_use))
		note_to_use = Note(defl_volts_wave)
	endif
	Make /O/N=0 defl_meters,z_meters
	Variable z_lvdt_sensitivity = GV("ZLVDTSens")
	Variable invols = (GV("Invols"))
	volts_to_meters(zsnsr_volts_wave,defl_volts_wave,z_lvdt_sensitivity,invols,z_meters,defl_meters)
	// save the zsnsr and defl to the disk
	save_to_disk(z_meters,defl_meters,note_to_use)
	KillWaves /Z defl_meters,z_meters
End Function

Static Function save_to_disk(zsnsr_wave,defl_wave,note_to_use)
	// Saves the given ZSnsr and deflection to disk
	//
	// Args:
	//	zsnsr_wave: Assumed ends with "ZSnsr", the Z Sensor in meters
	//	defl_wave: the deflection in meters
	// 	note_to_use: the (optional) note to save with. defaults to just defl_wave
	// Returns
	//	Nothing
	Wave zsnsr_wave,defl_wave
	String note_to_use
	Variable save_to_disk = 0x2;
	Duplicate /O zsnsr_wave,raw_wave
	// For ARSaveAsForce... (modelled after DE_SaveFC, 2017-6-5)
	// Args:
	//	1: 0x10 means 'save to disk, not memory'
	//	2: "SaveForce" is the symbolis path name 
	//	3: what we are saving (in addition to ZSnsr, or 'raw', which is required)
	//	4,5 : the actual waves
	//	6-10: empty waves (not saving)
	//	11: CustomNote: the note we are using toe save eveything
	ModForceModifications#prh_ARSaveAsForce(save_to_disk,"SaveForce","ZSnsr;Defl",raw_wave,zsnsr_wave,defl_wave,$"",$"",$"",$"",CustomNote=note_to_use)
	// Clean up the wave we just made
	KillWaves /Z raw_wave
End Function


Static Function assert_infastb_correct([input_needed,msg_on_fail])
	// asserts that infastb on the cross point panel matches the needed input
	//
	// Args:
	//	input_needed: string (ADC name) we wand connected to infastb. Default: "Defl"
	//	msg_on_fail: what to do if we fail
	// Returns:
	//	Nothing, throws an error if things go wrong
	String input_needed,msg_on_fail
	String in_fast_a = ModAsylumInterface#get_InFastA() 
	// Determine the faillure method based on what we want to connect	
	if (ParamIsDefault(input_needed))
		input_needed = "Defl"
	endif
	if (ParamIsDefault(msg_on_fail))
		msg_on_fail = "InFastB must be connected to " + input_needed + ", not " + in_fast_a
	EndIf		
	Variable correct_input = ModIoUtil#strings_equal(in_fast_a,input_needed)
	ModErrorUtil#assert(correct_input,msg=msg_on_fail)	
End Function

Static Function /S get_InFastA()
	// Returns: 
	//	the name of the ADC connected to InFastA
	String crosspoint_panel = "CrosspointPanel"
	ModErrorUtil#assert(ModPlotUtil#window_exists(crosspoint_panel),msg="Crosspoint panel doesn't exist")
	ControlInfo /W=$(crosspoint_panel) CypherInFastBPopup
	// S_Value is 'set to text of the current item'
	return S_Value
End Function