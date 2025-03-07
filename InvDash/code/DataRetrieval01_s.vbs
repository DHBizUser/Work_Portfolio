''--------------------------------------
''Set this folder path so you know where to find your output data
''--------------------------------------

dim DataFolder
DataFolder = "C:\Users\harrisdm\Documents\SAP\SAP GUI\DataFolder_20250305"

dim FirstDayofMonth
FirstDayofMonth = "2025-03-01"

dim LastDayofMonth
LastDayofMonth = "2025-03-31"



''--------------------------------------
''Establish SAP Connection
''--------------------------------------

''Log in first, start from SESSION_MANAGER.
''This is the boilerplate that is at the top of all recorded scripts.

If Not IsObject(application) Then
   Set SapGuiAuto  = GetObject("SAPGUI")
   Set application = SapGuiAuto.GetScriptingEngine
End If
If Not IsObject(connection) Then
   Set connection = application.Children(0)
 End If
If Not IsObject(session) Then
   Set session    = connection.Children(0)
End If
If IsObject(WScript) Then
   WScript.ConnectObject session,     "on"
   WScript.ConnectObject application, "on"
End If


''Open an extra window in case you want to use SAP while the script is still running

session.createSession

''--------------------------------------
'' MB51
''--------------------------------------

''Go to MB51 screen

session.findById("wnd[0]/tbar[0]/okcd").text = "mb51"
session.findById("wnd[0]").sendVKey 0


''select plant and date range

session.findById("wnd[0]/usr/ctxtWERKS-LOW").text = "RM06"
session.findById("wnd[0]/usr/ctxtBUDAT-LOW").text = FirstDayofMonth
session.findById("wnd[0]/usr/ctxtBUDAT-HIGH").text = LastDayofMonth
session.findById("wnd[0]/tbar[1]/btn[8]").press

''select grid view

session.findById("wnd[0]/tbar[1]/btn[48]").press

''select layout "DH_GRCONS"

session.findById("wnd[0]/mbar/menu[3]/menu[2]/menu[1]").select
session.findById("wnd[1]/usr/ssubD0500_SUBSCREEN:SAPLSLVC_DIALOG:0501/cntlG51_CONTAINER/shellcont/shell").currentCellRow = 139
session.findById("wnd[1]/usr/ssubD0500_SUBSCREEN:SAPLSLVC_DIALOG:0501/cntlG51_CONTAINER/shellcont/shell").clickCurrentCell
session.findById("wnd[0]/mbar/menu[0]/menu[1]/menu[2]").select
session.findById("wnd[1]/usr/subSUBSCREEN_STEPLOOP:SAPLSPO5:0150/sub:SAPLSPO5:0150/radSPOPLI-SELFLAG[1,0]").select

''Save list to a spreadsheet file

session.findById("wnd[1]/tbar[0]/btn[0]").press
session.findById("wnd[1]/usr/ctxtDY_PATH").text = DataFolder
session.findById("wnd[1]/usr/ctxtDY_FILENAME").text = "MB51_s.txt"
session.findById("wnd[1]/usr/ctxtDY_FILE_ENCODING").text = "1101"
session.findById("wnd[1]/tbar[0]/btn[0]").press

''Back out to of MB51 to go to next screen

session.findById("wnd[0]/tbar[0]/btn[12]").press
session.findById("wnd[0]/tbar[0]/btn[12]").press
session.findById("wnd[0]/tbar[0]/btn[12]").press

''--------------------------------------
'' CM01
''--------------------------------------

''Go to CM01 screen

session.findById("wnd[0]/tbar[0]/okcd").text = "CM01"
session.findById("wnd[0]").sendVKey 0

''Planning -> Selection -> Work Center

session.findById("wnd[0]/mbar/menu[0]/menu[1]/menu[0]").select
session.findById("wnd[1]/tbar[0]/btn[6]").press
session.findById("wnd[2]/tbar[0]/btn[6]").press

''Select Individual work Center

session.findById("wnd[2]/tbar[0]/btn[0]").press
session.findById("wnd[0]/mbar/menu[0]/menu[1]/menu[1]").select

''select all the work Centers

session.findById("wnd[1]/tbar[0]/btn[0]").press

''Planning -> Selection -> Capacity Center

session.findById("wnd[0]/mbar/menu[0]/menu[1]/menu[1]").select
session.findById("wnd[1]/usr/txt[35,3]").text = "008"
session.findById("wnd[1]/usr/txt[35,3]").caretPosition = 3
session.findById("wnd[1]/tbar[0]/btn[0]").press

''Detailed Capacity List

session.findById("wnd[0]/tbar[1]/btn[6]").press
session.findById("wnd[0]/tbar[1]/btn[20]").press
session.findById("wnd[1]/usr/subSUBSCREEN_STEPLOOP:SAPLSPO5:0150/sub:SAPLSPO5:0150/radSPOPLI-SELFLAG[1,0]").select

''Download and Save File

session.findById("wnd[1]/tbar[0]/btn[0]").press
session.findById("wnd[1]/usr/ctxtDY_PATH").text = DataFolder
session.findById("wnd[1]/usr/ctxtDY_FILENAME").text = "CM01_s.txt"
session.findById("wnd[1]/usr/ctxtDY_FILE_ENCODING").text = "1101"
session.findById("wnd[1]/tbar[0]/btn[0]").press

''Back out to of CM01 to go to next screen

session.findById("wnd[0]/tbar[0]/btn[12]").press
session.findById("wnd[0]/tbar[0]/btn[12]").press
session.findById("wnd[0]/tbar[0]/btn[12]").press


''--------------------------------------
'' ZOTIF
''--------------------------------------

''Go to ZOTIF screen

session.findById("wnd[0]/tbar[0]/okcd").text = "ZOTIF"
session.findById("wnd[0]").sendVKey 0

''Open up the list of variants

session.findById("wnd[0]/mbar/menu[2]/menu[0]/menu[0]").select
session.findById("wnd[1]/usr/txtENAME-LOW").text = ""
session.findById("wnd[1]/tbar[0]/btn[8]").press

''Select variant "SW_FERT"

session.findById("wnd[1]/usr/cntlALV_CONTAINER_1/shellcont/shell").selectedRows = "0"
session.findById("wnd[1]/tbar[0]/btn[2]").press

''Run the report

session.findById("wnd[0]/tbar[1]/btn[8]").press

''Save as spreadsheet file

session.findById("wnd[0]/mbar/menu[0]/menu[3]/menu[2]").select
session.findById("wnd[1]/usr/subSUBSCREEN_STEPLOOP:SAPLSPO5:0150/sub:SAPLSPO5:0150/radSPOPLI-SELFLAG[1,0]").select
session.findById("wnd[1]/tbar[0]/btn[0]").press
session.findById("wnd[1]/usr/ctxtDY_PATH").text = DataFolder
session.findById("wnd[1]/usr/ctxtDY_FILENAME").text = "ZOTIF_s.txt"
session.findById("wnd[1]/usr/ctxtDY_FILE_ENCODING").text = "1101"
session.findById("wnd[1]/tbar[0]/btn[0]").press

''Back out to of ZOTIF to go to next screen

session.findById("wnd[0]/tbar[0]/btn[12]").press
session.findById("wnd[0]/tbar[0]/btn[12]").press


''--------------------------------------
'' MB52
''--------------------------------------

''Go to MB52 screen

session.findById("wnd[0]/tbar[0]/okcd").text = "MB52"
session.findById("wnd[0]").sendVKey 0


''Enter input parameters, use "/YZRED" layout

session.findById("wnd[0]/usr/ctxtWERKS-LOW").text = "RM06"
session.findById("wnd[0]/usr/chkXMCHB").selected = true
session.findById("wnd[0]/usr/chkNOZERO").selected = true
session.findById("wnd[0]/usr/ctxtP_VARI").text = "/YZRED"
session.findById("wnd[0]/tbar[1]/btn[8]").press

''Save as a Spreadsheet

session.findById("wnd[0]/tbar[1]/btn[45]").press
session.findById("wnd[1]/usr/subSUBSCREEN_STEPLOOP:SAPLSPO5:0150/sub:SAPLSPO5:0150/radSPOPLI-SELFLAG[1,0]").select
session.findById("wnd[1]/tbar[0]/btn[0]").press

session.findById("wnd[1]/usr/ctxtDY_PATH").text = DataFolder
session.findById("wnd[1]/usr/ctxtDY_FILENAME").text = "MB52_s.txt"
session.findById("wnd[1]/usr/ctxtDY_FILE_ENCODING").text = "1101"
session.findById("wnd[1]/tbar[0]/btn[0]").press

''Back out to of MB52 to go to next screen

session.findById("wnd[0]/tbar[0]/btn[12]").press
session.findById("wnd[0]/tbar[0]/btn[12]").press


''--------------------------------------
'' Forecast Report
''--------------------------------------

''Go to SQ00 screen

session.findById("wnd[0]/tbar[0]/okcd").text = "SQ00"
session.findById("wnd[0]").sendVKey 0
