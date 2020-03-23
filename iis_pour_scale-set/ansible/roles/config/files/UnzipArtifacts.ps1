
#this is the number of unzip process that will run in same time
$limitprocesscount = 30


#this is the name of the file that if it exists , it should be unzipped
$zippedfilename = 'Package.zip'

#this is a sting we will use in the log files
$FoundZippedFile="`n`n`n`n`nthe zipped file $zippedfilename has been found for the following environments:" 




#the variable $limitprocesscount define the number of 7z processes that should run in parallel but for each instance of 7z we have 2 process so we will double the number
$Reallimitprocesscount = $limitprocesscount * 2

#define an array, this array will be used to save the id of Unzip Jobs as they will run synchronously in the background
$UnzipJobID = New-Object System.Collections.ArrayList 



$websitephysicalpathPrefix = 'c:\inetpub\'

#this is the logfile where we will register the Errors. if any errors are found this log will not be deleted
$ErrorLogFile = 'c:\UnzipArtifactsErrorLog.txt'
remove-item -force $ErrorLogFile -ErrorAction SilentlyContinue

#this is the execution logfile, it is created just to let a loged-in user to know where the script has get in the processing. it will be deleted at the end of the script
$ExecutionLogFile = 'c:\UnzipArtifactsExecutionLog.txt'
remove-item -force $ExecutionLogFile -ErrorAction SilentlyContinue

#get the list of all IIS websites
#$ListOfWebsites = $ListOfWebsitesa -split " "
$ListOfWebsites = $(c:\Windows\System32\inetsrv\appcmd list site | %{$_.split(' ')[1]}  )



#define an array, this array will be used to save the id of Unzip Jobs that has failed the first time and they have been initiated a second time
$SeconTryUnzipJobID = New-Object System.Collections.ArrayList 

#define an array, this array will be used to save the id of Unzip Jobs that has failed the Second time and will be launched for third time
$ThirdTryUnzipJobID = New-Object System.Collections.ArrayList 

echo "`n`n`n`n`n`n`nstart unzip"
Get-Date
#reset the timer so we check how long the unzip operation will take
$sw = [System.Diagnostics.StopWatch]::startNew()



#############################################launching first time unzip########################

$arraylength = $ListOfWebsites.Length
#rotate through each IIS website
For ($i=0 ; $i -lt $arraylength ; $i++)
{
        $sitename = "$($ListOfWebsites[$i]  | %{$_ -replace '"', ''} )"
       if ("$sitename" -eq "Default")
       {
           continue
       }
        #this is the physical path where the artifact should be download
        $websitephysicalpath = "${websitephysicalpathPrefix}${sitename}"


            
      $processcount = (get-job -Command "7z.exe*" |where {$_.State -eq "Running"}).count
    
     
      while ($processcount -gt $limitprocesscount)
      {
          echo "sleeping because the number of processes is $processcount"
          sleep 20
          $processcount = (get-job -Command "7z.exe*" |where {$_.State -eq "Running"}).count

      }

        #check if the file Package.zip exists under wwwroot
        $DoesZipExistUnderRoot = Test-Path "${websitephysicalpath}\wwwroot\${zippedfilename}"
        if ($DoesZipExistUnderRoot  -eq "True")
        {
            $blobcontainernamedot = "$($sitename | %{$_ -replace '.az.radio-canada.ca', ''}  )"
            #we will replace the . with a -
            $blobcontainername = "$($blobcontainernamedot | %{$_ -replace '\.', '-'} )"
            $UnzipJobName= "${blobcontainername}-unzip"

            $dpath = "${websitephysicalpath}\wwwroot"

            $fileToUnzip = "${dpath}\${zippedfilename}"
            echo "      - Initiating the unzip of the file $fileToUnzip into $dpath"
            echo "      - Initiating the unzip of the file $fileToUnzip into $dpath" | Out-File -Append -FilePath "$ExecutionLogFile"
            $object = Start-Job -Name "$UnzipJobName"  -ScriptBlock {7z.exe x -aoa -mmt=100 -o"$($args[1])"  "$($args[0])" -r -y } -ArgumentList "$fileToUnzip", "$dpath"

            $NewRecord=New-Object PSObject -Property @{
                         JobName = $UnzipJobName
                         blobtounzip = $fileToUnzip
                         DestinationPath = $dpath
            }

            #add the record to the array
            $UnzipJobID.Add($NewRecord) > $null
             $FoundZippedFile = "$FoundZippedFile `n-SiteName: $sitename        FileToUnzip: ${dpath}\${zippedfilename}  UnzipIN: $dpath"
            
        }





        #check if the file Package.zip exists under pages
        $DoesZipExistUnderRoot = Test-Path "${websitephysicalpath}\pages\${zippedfilename}"
        if ($DoesZipExistUnderRoot  -eq "True")
        {
            $blobcontainernamedot = "$($sitename | %{$_ -replace '.az.radio-canada.ca', ''}  )"
            #we will replace the . with a -
            $blobcontainername = "$($blobcontainernamedot | %{$_ -replace '\.', '-'} )"
            $pageblobcontainername="${blobcontainername}-pages"
            $UnzipJobName= "${pageblobcontainername=}-unzip"

            $dpath = "${websitephysicalpath}\pages"

            $fileToUnzip = "${dpath}\${zippedfilename}"
            echo "      - Initiating the unzip of the file $fileToUnzip into $dpath" 
            echo "      - Initiating the unzip of the file $fileToUnzip into $dpath" | Out-File -Append -FilePath "$ExecutionLogFile"
            $object = Start-Job -Name "$UnzipJobName"  -ScriptBlock {7z.exe x -aoa -mmt=100 -o"$($args[1])"  "$($args[0])" -r -y } -ArgumentList "$fileToUnzip", "$dpath"

            $NewRecord=New-Object PSObject -Property @{
                         JobName = $UnzipJobName
                         blobtounzip = $fileToUnzip
                         DestinationPath = $dpath
            }

            #add the record to the array
            $UnzipJobID.Add($NewRecord) > $null
            $FoundZippedFile = "$FoundZippedFile `n-SiteName: $sitename        FileToUnzip: ${dpath}\${zippedfilename}  UnzipIN: $dpath"
            
        }


}




#############################################Waiting first time unzip to Finish and launching Second Time Unzip########################


$HoldFirstUnzipError = ""
#rotate through each Unzip job running in the background
foreach ($job in $UnzipJobID) {
  
  $JobName = $job.JobName
  $Destination = $job.DestinationPath
  $PathToFileToUnzip = $job.blobtounzip 
  echo "`n`n`n`n`n`n- waiting to unzip: $PathToFileToUnzip        into $Destination" 
  echo "`n`n`n`n`n`n- waiting to unzip: $PathToFileToUnzip        into $Destination"  | Out-File -Append -FilePath $ExecutionLogFile

 



  #wait for the job to finish
  $waitjob = Wait-Job -name $JobName

  #capture only the Error output 
  Receive-Job -Name $JobName -ErrorVariable ErrorMessage >$null 2>$null
  if ($ErrorMessage)
  {
                    $UnzipJobName= "${JobName}-secondTime"

                    #if the unzip has failed we will try again

                    echo "  WARNING: failed the first try to unzip: $PathToFileToUnzip        into $Destination `n     Error Message of First time was: $ErrorMessage `n`n`n  Lanching the unzip for the second time"
                    echo "  WARNING: failed the first try to unzip: $PathToFileToUnzip        into $Destination `n     Error Message of First time was: $ErrorMessage `n`n`n  Lanching the unzip for the second time"| Out-File -Append -FilePath $ExecutionLogFile
                    $HoldFirstUnzipError = "$HoldFirstUnzipError `n WARNING: failed the first try to unzip: $PathToFileToUnzip    `n     Error Message of First time was: $ErrorMessage"
                    #invoke-command -ScriptBlock {Expand-Archive -Path "$($args[0])"  -DestinationPath "$($args[1])" -Force} -ArgumentList "$PathToFileToUnzip", "$Destination" -ErrorVariable SecondTryErrorMessage  >$null 2>$null
                    $object = Start-Job -Name "$UnzipJobName"  -ScriptBlock {7z.exe x -aoa -mmt=100 -o"$($args[1])"  "$($args[0])" -r -y} "$PathToFileToUnzip", "$Destination" 
  
        
        #create a record which contains the name of the job running in the background, the full-path to the file to unzip and the destination path where it shoudl be unzippped
        #$JobArray.Add($object) > $null
                    $NewRecord=New-Object PSObject -Property @{
                         JobName = $UnzipJobName
                         blobtounzip = $PathToFileToUnzip
                         DestinationPath = $Destination
                    }

                    #add the record to the array
                    $SeconTryUnzipJobID.Add($NewRecord) > $null
             

  #closure of if ($ErrorMessage)
  }


#closure of  foreach ($job in $UnzipJobID)
}







#############################################Waiting Second time unzip to Finish########################



$HoldSecondUnzipError = ""
$NumberOfUnzipJobSeconTry = $SeconTryUnzipJobID.count
echo "`n`n`n`n`n`n`n`nthe number of unzip jobs that have been launched for the second time is: $NumberOfUnzipJobSeconTry" 
echo "`n`n`n`n`n`n`n`nthe number of unzip jobs that have been launched for the second time is: $NumberOfUnzipJobSeconTry" | Out-File -Append -FilePath $ExecutionLogFile
#if there is unzip jobs that were launched for the second time we will wait for them
#rotate through each Unzip job running in the background
foreach ($job in $SeconTryUnzipJobID) {
  
  $JobName = $job.JobName
  $Destination = $job.DestinationPath
  $PathToFileToUnzip = $job.blobtounzip 

  echo "`n`n`n`n`n`n- waiting for the second try, to unzip: $PathToFileToUnzip        into $Destination" 
  echo "`n`n`n`n`n`n- waiting for the second try, to unzip: $PathToFileToUnzip        into $Destination"  | Out-File -Append -FilePath $ExecutionLogFile

 



  #wait for the job to finish
  $waitjob = Wait-Job -name $JobName

  #capture only the Error output 
  Receive-Job -Name $JobName -ErrorVariable ErrorMessage >$null 2>$null
  if ($ErrorMessage)
  {
       #write the errors to the execution log
                          #echo "  for the second time, ERROR Unzipping Package.zip `n     Error Message was: $ErrorMessage"| Out-File -Append -FilePath $ExecutionLogFile
                          #write the errors to the error log   
                          #echo "- for the second time,ERROR Unzipping `n of: $PathToFileToUnzip   `n  To The Path:  $Destination `n  Error Message: $ErrorMessage" | Out-File -Append -FilePath $ErrorLogFile
                           echo "  WARNING: for the second time,failing to unzip: $PathToFileToUnzip        into $Destination `n     Error Message was: $ErrorMessage"
                           echo "  WARNING: for the second time,failing to unzip: $PathToFileToUnzip        into $Destination `n     Error Message was: $ErrorMessage"| Out-File -Append -FilePath $ExecutionLogFile
                           $HoldSecondUnzipError = "$HoldSecondUnzipError  `nWARNING: for the second time,failing to unzip: $PathToFileToUnzip    `n     Error Message was: $ErrorMessage"

                          $NewRecord=New-Object PSObject -Property @{
                             $JobNameThirdTime = $job.JobName
                             $DestinationThirdTime = $job.Destination 
                              $PathToFileToUnzipThirdTime = $job.PathToFileToUnzip
                          }

                           #add the record to the array
                           $ThirdTryUnzipJobID.Add($NewRecord) > $null
             


  }
}




#############################################Wlaunching Third Time Unzip########################

$NumberOfUnzipJobThirdTry = $ThirdTryUnzipJobID.count
echo "`n`n`n`n`n`n`n`nthe number of unzip job to be launched for the Third time is: $NumberOfUnzipJobThirdTry" 
echo "`n`n`n`n`n`n`n`nthe number of unzip job to be launched for the Third time is: $NumberOfUnzipJobThirdTry" | Out-File -Append -FilePath $ExecutionLogFile
#if there is unzip jobs that were launched for the second time we will wait for them
#rotate through each Unzip job running in the background
foreach ($job in $ThirdTryUnzipJobID) {
                         $JobName = $job.JobNameThirdTime
                         $Destination = $job.DestinationThirdTime
                         $PathToFileToUnzip = $job.PathToFileToUnzipThirdTime

                          echo "  WARNING: Trying for the third time to unzip: $PathToFileToUnzip        into $Destination" 
                          echo "  WARNING: Trying for the third time to unzip: $PathToFileToUnzip        into $Destination" | Out-File -Append -FilePath $ExecutionLogFile
                         #launching third time unzip
                          invoke-command -ScriptBlock {7z.exe x -aoa -mmt=100 -o"$($args[1])"  "$($args[0])" -r -y } -ArgumentList "$PathToFileToUnzip", "$Destination" -ErrorVariable ThirddTryErrorMessage  >$null 2>$null
                          #if an error is found, log the error
                          f ("$ThirddTryErrorMessage")
                          {
                               echo "- ERROR: for the third time,ERROR Unzipping `n of: $PathToFileToUnzip   `n  To The Path:  $Destination `n  Error Message: $ErrorMessage"
                               echo "- ERROR: for the third time,ERROR Unzipping `n of: $PathToFileToUnzip   `n  To The Path:  $Destination `n  Error Message: $ErrorMessage" | Out-File -Append -FilePath $ErrorLogFile
                              
                          }
}
















echo "`n`n`n`n`n`n`n`n`nEnd of Unzipping. the time is"
get-date
echo "the elapsed time since start of unzipping is:"
$sw.Stop()
Write-Host $sw.Elapsed








#if errors Unzipping the file, has been found, append to the errorlog, the names of the environments for which the zip file has been found
#so we will know how many zip file should be unzipped and how many has succeeded
$DoesErrorLogExist = Test-Path -Path $ErrorLogFile
if ("$DoesErrorLogExist" -eq $True)
{
    echo "`n`n`n`n`n`n`n $FoundZippedFile" | Out-File -Append -FilePath $ErrorLogFile
    echo "`n`n`n`n`n`nthe number of unzip that have failed the first Time is: $NumberOfUnzipJobSeconTry the error messages are: `n$HoldFirstUnzipError `n`n" | Out-File -Append -FilePath $ErrorLogFile
    echo "`n`n`n`n`n`nthe number of unzip that have failed the Second Time is: $NumberOfUnzipJobThirdTry the error messages are: `n$HoldSecondUnzipError `n`n" | Out-File -Append -FilePath $ErrorLogFile
    
    #deleting the exection log file
    remove-item -force $ExecutionLogFile -ErrorAction SilentlyContinue

    #send email
    $Hostname = hostname
    $ipaddr = (Get-NetIPAddress -AddressFamily IPv4).IPv4Address | where {$_ -ne '127.0.0.1'} 
    $scriptName= $MyInvocation.MyCommand.Name 
   
     $message = "the Script Which Unzip the Artifacts has failed: `n  - ScriptName: ${PSScriptRoot}\${scriptName} `n  - Server Name: $Hostname `n  - Server Ip: $ipaddr `n`n`nTo avoid Errors, The Default Website is still disabled as result the server will not respond to probes from the loadbalancer"
     
     echo "sending email because some unzip have failed"
     Send-MailMessage -From 'UnzipArtifcactScript <noreply@radio-canada.ca>' -To 'devops <devops-mn-grp@radio-canada.ca>' -Subject 'Unzip Artifact Failure' -Body "$message" -SmtpServer 'smtpout.radio-canada.ca'
 
    #power off the virtual machine
    #Stop-Computer -Force

    throw "some websites have failed to unzip their artifacts"


    
    exit 1
}






#enabling iis DefaultWebsite
echo "as all unzip have succeeded, enabling default website"
Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.applicationHost/sites/site[@name='Default Web Site']" -name "serverAutoStart" -value "True"
if ("$?" -eq $False)
{
    echo  "the scirpt has successfully unzipped the artifacts but it has failed to enable The Default Website, as result the server will not respond to probes from the loadbalancer `nso please just enable the default website using the following command: `n`nSet-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter 'system.applicationHost/sites/site[@name='Default Web Site']' -name 'serverAutoStart' -value 'True' `n`niisreset" | Out-File -Append -FilePath $ErrorLogFile
  #send email
    $Hostname = hostname
    $ipaddr = (Get-NetIPAddress -AddressFamily IPv4).IPv4Address | where {$_ -ne '127.0.0.1'} 
    $scriptName= $MyInvocation.MyCommand.Name 
   
     $message = "ERROR: although, the Script Which Unzip the Artifacts has succeeded. it has failed to enable the default website: `n  - ScriptName: ${PSScriptRoot}\${scriptName} `n  - Server Name: $Hostname `n  - Server Ip: $ipaddr `n`n`nthe scirpt has successfully unzipped the artifacts but it has failed to enable The Default Website as result the server will not respond to probes from the loadbalancer. the Default website should be enabled on startup and iis should be restarted, please check the log file on the C drive for more details"
     
     echo "sending email because some unzip have failed"
     Send-MailMessage -From 'UnzipArtifcactScript <noreply@radio-canada.ca>' -To 'devops <devops-mn-grp@radio-canada.ca>' -Subject 'Unzip Artifact Failure' -Body "$message" -SmtpServer 'smtpout.radio-canada.ca'
 
}


#deleting the exection log file
remove-item -force $ExecutionLogFile -ErrorAction SilentlyContinue

echo "restarting iis"
iisreset /start




echo "deleting the zip file for all environments"

#######now we will delete the zipped files
#rotate through each IIS website
For ($i=0 ; $i -lt $arraylength ; $i++)
{
   $sitename = "$($ListOfWebsites[$i]  | %{$_ -replace '"', ''} )"
       if ("$sitename" -eq "Default")
       {
           continue
       }
         #this is the physical path where the artifact should be download
         $websitephysicalpath = "${websitephysicalpathPrefix}${sitename}"
         echo "deleting inside $websitephysicalpath"

           Remove-Item -force $websitephysicalpath\pages\${zippedfilename}  -Confirm:$false   -ErrorAction SilentlyContinue
           Remove-Item -force $websitephysicalpath\wwwroot\${zippedfilename} -Confirm:$false  -ErrorAction SilentlyContinue


}


for ($i=0;$i -lt 3;$i++)
{

  $DefaultWebsiteState = Get-Website -Name "Default Web Site" | foreach {$_.State}

  if ("$DefaultWebsiteState" -ne "Started")
  {
      Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.applicationHost/sites/site[@name='Default Web Site']" -name "serverAutoStart" -value "True" -ErrorVariable EnableDefaultWebsiteErrorSec
      iisreset 
  }
  else
  {
      break
  }
}


 $DefaultWebsiteState = Get-Website -Name "Default Web Site" | foreach {$_.State}
  if ("$DefaultWebsiteState" -ne "Started")
  {
      echo "ERROR: after 3 retries of restarting IIS, default website is still not started" | Out-File -Append -FilePath  $ErrorLogFile
        throw "failed to start the Default Website"
        exit 1
  }









exit 0