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

property gLogDirectory : gPrefix & "/var/log/PlasmaClient"
property gLogFile : ""
property gLogLink : gLogDirectory & "/PlasmaClient.log"
property kKeepLogs : 10

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
	set gLogFile to gLogDirectory & "/PlasmaClient." & timeSinceEpoch() & ".log"
end will finish launching

on should quit after last window closed theObject
	return true
end should quit after last window closed

on awake from nib theObject
	set theMessage to getContentsOfWebPage("http://support.cyanworlds.com/serverstatus/moullive.php")
	tell user defaults
		set theUsername to contents of default entry "username"
		set thePassword to contents of default entry "password"
	end tell
	tell content view of theObject
		if theMessage is not "" then
			set contents of text field "Welcome Message" to theMessage
		end if
		set contents of text field "Username Field" to theUsername
		set contents of text field "Password Field" to thePassword
		tell button "Remember Password Checkbox"
			if thePassword is "" and theUsername is not "" then
				set state to 0
			else
				set state to 1
			end if
		end tell
	end tell
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
		set rememberPassword to (state of button "Remember Password Checkbox" is 1)
		if rememberPassword then
			set thePassword to contents of text field "Password Field"
		else
			set thePassword to ""
		end if
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
		checkForGameFiles()
	end if
end clicked

on checkForGameFiles()
	set haveGameFiles to itemExists(gDataDirectory & "/dat")
	if haveGameFiles then
		startAuthentication()
	else
		display dialog "PlasmaClient needs the Myst Online: URU Live again game data files. Please install the “mystonline-cider” port and run the application to let it download all the game data." buttons {"OK"} default button "OK" attached to window "Login Window"
	end if
end checkForGameFiles

on startAuthentication()
	showProgressPanel("Authenticating…")
	
	tell window "Login Window"
		set theUsername to contents of text field "Username Field"
		set thePassword to contents of text field "Password Field"
	end tell
	
	if itemExists(gLogLink) then
		deleteFile(gLogLink)
	end if
	makeLink(gLogFile, gLogLink)
	set gStatusFile to makeTempFile()
	set gPid to (do shell script "(" & quoted form of gPlasmaClientForAuth & " " & quoted form of theUsername & " " & quoted form of thePassword & " -t >& " & quoted form of gLogFile & "; echo $?) >& " & quoted form of gStatusFile & " & echo $!")
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
	
	set gPid to (do shell script "(cd " & quoted form of gDataDirectory & " && " & quoted form of gPlasmaClientForGame & " " & quoted form of theUsername & " " & quoted form of thePassword & ") >& " & quoted form of gLogFile & " & echo $!")
	
	set theLogFiles to listDirectory(gLogDirectory, "PlasmaClient.*.log")
	repeat with i from 1 to (count theLogFiles) - kKeepLogs
		deleteFile(item i of theLogFiles)
	end repeat
	
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

on listDirectory(theDirectory, theGlob)
	return paragraphs of (do shell script "ls " & quoted form of theDirectory & "/" & theGlob)
end listDirectory

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

on makeLink(fromItem, toItem)
	do shell script "ln -s " & quoted form of fromItem & " " & quoted form of toItem
end makeLink

on timeSinceEpoch()
	return (do shell script "date '+%s'")
end timeSinceEpoch

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
