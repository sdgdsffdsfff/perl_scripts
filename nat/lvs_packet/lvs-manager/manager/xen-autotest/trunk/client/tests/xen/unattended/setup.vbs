Const ForReading = 1
Const ForWriting = 2

strScriptFolder = "C:\qescripts"
strRssName = "RSS"
strRssPath = "C:\qescripts\rss.exe"
strRssDispName = "Remote Shell Server"
strScriptLog = "C:\qescripts\test.log"
strTelnetServiceName = "TlntSvr"

Dim strWinVersion

Set objFSO = CreateObject("Scripting.FileSystemObject")

If Not objFSO.FolderExists(strScriptFolder) Then
	objFSO.CreateFolder(strScriptFolder)
End If

If Not objFSO.FileExists(strScriptLog) Then
	objFSO.CreateTextFile(strScriptLog)
End If

Set qeLog = objFSO.OpenTextFile(strScriptLog, ForWriting, True)

If not objFSO.FileExists("A:\rss.exe") Then
	qeLog.WriteLine "Error : Cannot find rss.exe in floppy"
	WScript.Quit 1
End If
	
Set objFileCopy = objFSO.GetFile("A:\rss.exe")
qeLog.WriteLine "Copying A:\rss.exe " & "from floppy" & " to " & strScriptFolder
objFileCopy.Copy (strRssPath)

Function disableFirewall(logFile)
	REM just ignore the error of firewall service
	On Error Resume Next
        Set objFirewall = CreateObject("HNetCfg.FwMgr")
        Set objPolicy = objFirewall.LocalPolicy.CurrentProfile
        objPolicy.FirewallEnabled = FALSE
	On Error Goto 0
End Function

Function installService(strServiceName, strSrvDispName, strSrvPath, strMode, logFile)

        Const KERNEL_DRIVER = 1
        Const FS_DRIVER = 2
        Const ADAPTER = 4
        Const RECOGNIZER_DRIVER = 8
        Const OWN_PROCESS = 16
        Const SHARE_PROCESS = 32
        Const INTERACTIVE_PROCESS = 256

        INTERACT_WITH_DESKTOP = FALSE

        Const NOT_NOTIFIED = 0
        Const USER_NOTIFIED = 1
        Const SYSTEM_RESTARTED = 2
        Const SYSTEM_STARTS = 3

	strComputer = "."
	Set objWMIService = GetObject("winmgmts:" _
	    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

	Set objService = objWMIService.Get("Win32_BaseService")
	intRetCode = objService.Create(strServiceName, strSrvDispName, _
		strSrvPath, OWN_PROCESS, USER_NOTIFIED, strMode, _
		INTERACT_WITH_DESKTOP, "NT AUTHORITY\LocalService", "" )
	If intRetCode <> 0 Then
		logFile.WriteLine "Install " & strServiceName & " service failed : Error Code = " & errReturn
	Else
		logFile.WriteLine "Install " & strServiceName & " service success."
	End If
End Function

Function startService(strServiceName, strMode, logFile)
	strComputer = "."
	Set objWMIService = GetObject("winmgmts:" _
    		& "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

	Set colServices = objWMIService.ExecQuery _
	    ("Select * from Win32_Service Where Name = '"& strServiceName &"' ")

	For Each objService in colServices
		logFile.WriteLine "Enabling the Service : " & objService.DisplayName
		logFile.WriteLine "Start Mode : " & strMode
		objService.ChangeStartMode(strMode)
		logFile.WriteLine "Starting the Service : " & objService.DisplayName
		objService.StartService()
	Next
End Function

Function deleteService(strServiceName, logFile)
	strComputer = "."
	logFile.WriteLine "Deleting service " & strServiceName
	Set objWMIService = GetObject("winmgmts:" _
	    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

	Set colListOfServices = objWMIService.ExecQuery _
	    ("Select * from Win32_Service Where Name = '"& strServiceName &"' ")
	For Each objService in colListOfServices
		logFile.WriteLine "Stopping the Service : " & objService.DisplayName
		objService.StopService()
		logFile.WriteLine "Deleting the Service : " & objService.DisplayName
		objService.Delete()
	Next
End Function

Function checkWinVersion(strVersion, logFile)
	strComputer = "."

	Set objWMIService = GetObject("winmgmts:" _
	    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

	Set colOperatingSystems = objWMIService.ExecQuery _
		("Select * from Win32_OperatingSystem")

	For Each objOperatingSystem in colOperatingSystems
		strSysVersion = objOperatingSystem.Caption & " " &_
			objOperatingSystem.Version
		logFile.WriteLine "Windows Version : " & strSysVersion
	Next

	Select Case True
		Case InStr(strSysVersion, "2003") <> 0: strVersion = "WIN2K3"
		Case InStr(strSysVersion, "Windows XP") <> 0: strVersion = "WINXP"
		Case InStr(strSysVersion, "Vista") <> 0: strVersion = "WINVISTA"
		Case InStr(strSysVersion, "2008") <> 0: strVersion = "WIN2K8"
		Case Else:  strVersion = "Unknown"
	End Select
End Function

Function installStartupScript(strScriptName, strScriptPath, logFile)
	Set objShell = WScript.CreateObject("Wscript.Shell")
	Startup = objShell.RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\Startup")
	objShell.Run "cmd /c Copy " & Chr(34) & strScriptPath & Chr(34) & " " & Chr(34) & Startup & Chr(34),vbHide
	RegName = strScriptPath
	RegData = strScriptName
	objShell.RegWrite "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run\" & RegName,RegData,"REG_SZ"
	set objShell = Nothing
End Function

checkWinVersion strWinVersion, qeLog

REM If strWinVersion = "WINXP" Then
REM 	qeLog.WriteLine "This is a Windows XP system"
REM 	disableFireWall qeLog
REM 	installStartupScript strRssName, strRssPath, qeLog
REM Else
REM 	qeLog.WriteLine "This is not Windows XP"
REM End If

REM installService strRssName, strRssDispName, strRssPath, "Automatic", qeLog
startService strTelnetServiceName, "Automatic", qeLog
REM deleteService strRssName, qeLog
REM disableFireWall qeLog
installStartupScript strRssName, strRssPath, qeLog
Set objShell = WScript.CreateObject("Wscript.Shell")
objShell.Run "%WINDIR%\System32\cmd /c C:\qescripts\rss.exe"

WScript.Quit 0
