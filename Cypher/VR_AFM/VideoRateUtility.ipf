// Use modern global access method, strict compilation
#pragma rtGlobals=3	

#pragma ModuleName = ModVideoRateUtility
#include "::OfflineAsylum"
#include ":::Util:IoUtil"


Static function main_rename([new_path,base_dir])
	// Fixes the FilePath part of the note for all ways in base_dir to correctly point to their file i new_path 
	//
	// Args:
	// 	 	new_path: igor-style path, where the data live on the disk. For some reason, igor
	//				doesn't include the actual file name in the "FilePath" part of  the ARIS note.
	//			       Instead of "foo:bar:file.ARIS", it is just "foo:bar:". This variable is the "foo:bar:" part
	// 		base_dir: where to replace the FilePath part of the notes. just looks in this one directory
	String new_path, base_dir
	if (ParamIsDefault(base_dir))
		base_dir = "root:Images:Browse:"
	endif
	if (ParamIsDefault(new_path))
		new_path = "C:Users:sba.apps:Desktop:PerkinsLab_Patrick:Day3:2019-5-5-Day3-#1-DNA-BSP-12.5U-mL:" 
	endif
	// Get all the waves in the directory 
	Variable n = ModIoUtil#CountWaves(base_dir)
	Variable i =0;
	for (i=0; i < n; i += 1)
		String new_wave = ModIoUtil#GetWaveAtIndex(base_dir,i,fullPath=1)
		Wave in_wave = $(new_wave)
		String old_file = ModOfflineAsylum#note_string(note(in_wave),"FileName",delim_key_val=":",delim_pairs=";")
		String new_tmp_path = new_path + old_file
		ModOfflineAsylum#replace_wave_note_string(in_wave,"FilePath",new_tmp_path,delim_key_val=":",delim_pairs=";")
	EndFor
End Function