-- PCLauncher.applescript
-- PCLauncher

-- Created by Ryan Schmidt on 2010-10-01.
-- Copyright 2010 __MyCompanyName__. All rights reserved.


-- Paths
property gPrefix : "/opt/local"
property gDrizzle : gPrefix & "/bin/drizzle"
property gDrizzleForDownload : gDrizzle
property gDrizzleForExtract : gDrizzle
property gPlasmaClient : gPrefix & "/bin/PlasmaClient"
property gPlasmaClientForAuth : gPlasmaClient
property gPlasmaClientForGame : gPlasmaClient
property gDataDirectory : gPrefix & "/share/mystonline/data"
property gPythonDirectory : gDataDirectory & "/python"
property gSdlDirectory : gDataDirectory & "/SDL"

-- Task enums
property kTaskIdle : 0
property kTaskWaitForAuthentication : 1
property kTaskWaitForSecureFilesToDownload : 2
property kTaskWaitForSecureFilesToExtract : 3

-- Current task
property gTask : kTaskIdle

-- Other globals
property gStatusFile : ""
property gSecureFilesDirectory : ""
property gProgressMax : 0
property gPid : 0

on will finish launching theObject
	make new default entry at end of default entries of user defaults with properties {name:"username", contents:""}
	make new default entry at end of default entries of user defaults with properties {name:"password", contents:""}
end will finish launching

on should quit after last window closed theObject
	return true
end should quit after last window closed

on awake from nib theObject
	tell user defaults
		set contents of text field "Username Field" of content view of theObject to contents of default entry "username"
		set contents of text field "Password Field" of content view of theObject to contents of default entry "password"
	end tell
	set theMessage to getContentsOfWebPage("http://support.cyanworlds.com/serverstatus/moullive.php")
	if theMessage is not "" then
		set contents of text field "Welcome Message" of content view of theObject to theMessage
	end if
	show theObject
end awake from nib

on idle theObject
	if gTask is kTaskWaitForAuthentication then
		waitForAuthentication()
	else if gTask is kTaskWaitForSecureFilesToDownload then
		waitForSecureFilesToDownload()
	else if gTask is kTaskWaitForSecureFilesToExtract then
		waitForSecureFilesToExtract()
	end if
	return 1
end idle

on end editing theObject
	savePrefs()
end end editing

on will close theObject
	-- still need to clear the first responder
	savePrefs()
end will close

on savePrefs()
	tell window "Login Window"
		set theUsername to contents of text field "Username Field"
		set thePassword to contents of text field "Password Field"
	end tell
	tell user defaults
		set contents of default entry "username" to theUsername
		set contents of default entry "password" to thePassword
	end tell
end savePrefs

on getContentsOfWebPage(theUrl)
	try
		return (do shell script "curl " & quoted form of theUrl)
	on error errMsg number errNum
		return ""
	end try
end getContentsOfWebPage

on clicked theObject
	if name of theObject is "Play Button" then
		startAuthentication()
	end if
end clicked

on startAuthentication()
	showProgressPanel("Authenticating…")
	
	tell window "Login Window"
		set theUsername to contents of text field "Username Field"
		set thePassword to contents of text field "Password Field"
	end tell
	
	set gStatusFile to makeTempFile()
	set gPid to (do shell script "(" & quoted form of gPlasmaClientForAuth & " " & quoted form of theUsername & " " & quoted form of thePassword & " -t >& /dev/null; echo $?) >& " & quoted form of gStatusFile & " & echo $!")
	set gTask to kTaskWaitForAuthentication
end startAuthentication

on waitForAuthentication()
	set theStatus to (do shell script "tail -n 1 " & quoted form of gStatusFile)
	
	if theStatus is "" then
		return
	end if
	
	deleteFile(gStatusFile)
	hideProgressPanel()
	if theStatus is "0" then
		checkForSecureFiles()
	else
		set gTask to kTaskIdle
		display dialog "Authentication failed. Check that you’ve entered the correct email address and password for your Myst Online: URU Live again account." buttons {"OK"} default button "OK" attached to window "Login Window"
	end if
end waitForAuthentication

on checkForSecureFiles()
	set haveSecureFiles to itemExists(gPythonDirectory) and itemExists(gSdlDirectory)
	if haveSecureFiles then
		startGame()
	else
		startDownloadingSecureFiles()
	end if
end checkForSecureFiles

on startDownloadingSecureFiles()
	showProgressPanel("Downloading secure game files…")
	
	tell window "Login Window"
		set theUsername to contents of text field "Username Field"
		set thePassword to contents of text field "Password Field"
	end tell
	
	set gStatusFile to makeTempFile()
	set gSecureFilesDirectory to makeTempDirectory()
	set gPid to (do shell script quoted form of gDrizzleForDownload & " -downloadsecuremoulagainfiles " & quoted form of theUsername & " " & quoted form of thePassword & " " & quoted form of gSecureFilesDirectory & " >& " & quoted form of gStatusFile & " & echo $!")
	set gTask to kTaskWaitForSecureFilesToDownload
end startDownloadingSecureFiles

on waitForSecureFilesToDownload()
	try
		set filesDownloaded to (do shell script "sed -n 's/^Transid=//p' " & quoted form of gStatusFile & " | tail -n 1") as number
	on error errMsg number errNum
		set filesDownloaded to 0
	end try
	if filesDownloaded is greater than 0 then
		if gProgressMax is 0 then
			makeProgressDeterminate(62)
		end if
		updateProgress(filesDownloaded)
	end if
	
	try
		do shell script "grep '^All done!$' " & quoted form of gStatusFile & " > /dev/null"
	on error errMsg number errNum
		return
	end try
	
	kill(gPid)
	deleteFile(gStatusFile)
	hideProgressPanel()
	startExtractingSecureFiles()
end waitForSecureFilesToDownload

on startExtractingSecureFiles()
	showProgressPanel("Extracting secure game files…")
	
	set gStatusFile to makeTempFile()
	set gPid to (do shell script quoted form of gDrizzleForExtract & " -decompilepak " & quoted form of (gSecureFilesDirectory & "/Python/python.pak") & " " & quoted form of (gSecureFilesDirectory & "/Python/python") & " moul >& " & quoted form of gStatusFile & " & echo $!")
	set gTask to kTaskWaitForSecureFilesToExtract
end startExtractingSecureFiles

on waitForSecureFilesToExtract()
	try
		set filesExtracted to (do shell script "grep '^Decompiling: ' " & quoted form of gStatusFile & " | wc -l") as number
	on error errMsg number errNum
		set filesExtracted to 0
	end try
	if filesExtracted is greater than 0 then
		if gProgressMax is 0 then
			makeProgressDeterminate(503)
		end if
		updateProgress(filesExtracted)
	end if
	
	try
		do shell script "grep '^Done decompiling!$' " & quoted form of gStatusFile & " > /dev/null"
	on error errMsg number errNum
		return
	end try
	
	deleteFile(gStatusFile)
	hideProgressPanel()
	moveSecureFilesIntoDataDir()
end waitForSecureFilesToExtract

on moveSecureFilesIntoDataDir()
	deleteDirectory(gPythonDirectory)
	deleteDirectory(gSdlDirectory)
	moveItem(gSecureFilesDirectory & "/Python/python", gPythonDirectory)
	moveItem(gSecureFilesDirectory & "/SDL", gSdlDirectory)
	deleteDirectory(gSecureFilesDirectory)
	startGame()
end moveSecureFilesIntoDataDir

on startGame()
	set gTask to kTaskIdle
	
	tell window "Login Window"
		set theUsername to contents of text field "Username Field"
		set thePassword to contents of text field "Password Field"
	end tell
	
	set gPid to (do shell script "(cd " & quoted form of gDataDirectory & " && " & quoted form of gPlasmaClientForGame & " " & quoted form of theUsername & " " & quoted form of thePassword & ") &>/dev/null & echo $!")
	
	quit
end startGame

on makeTempFile()
	return (do shell script "mktemp /tmp/PCLauncher.XXXXXXXX")
end makeTempFile

on makeTempDirectory()
	return (do shell script "mktemp -d /tmp/PCLauncher.XXXXXXXX")
end makeTempDirectory

on deleteFile(theFile)
	do shell script "rm -f " & quoted form of theFile
end deleteFile

on deleteDirectory(theDirectory)
	do shell script "rm -rf " & quoted form of theDirectory
end deleteDirectory

on itemExists(theItem)
	try
		do shell script "test -e " & quoted form of theItem
		return true
	end try
	return false
end itemExists

on kill(pid)
	do shell script "kill " & pid
end kill

on moveItem(fromItem, toItem)
	do shell script "mv " & quoted form of fromItem & " " & quoted form of toItem
end moveItem

on showProgressPanel(theMessage)
	set gProgressMax to 0
	tell window "Progress Panel"
		tell progress indicator "Progress Bar"
			set uses threaded animation to true
			set indeterminate to true
			start
		end tell
		tell text field "Progress Text"
			set contents to theMessage
		end tell
	end tell
	display window "Progress Panel" attached to window "Login Window"
end showProgressPanel

on makeProgressDeterminate(max)
	set gProgressMax to max
	tell window "Progress Panel"
		tell progress indicator "Progress Bar"
			set maximum value to max
			set content to 0
			set indeterminate to false
		end tell
	end tell
end makeProgressDeterminate

on updateProgress(step)
	tell window "Progress Panel"
		tell progress indicator "Progress Bar"
			set content to step
		end tell
	end tell
end updateProgress

on hideProgressPanel()
	close panel window "Progress Panel"
end hideProgressPanel
