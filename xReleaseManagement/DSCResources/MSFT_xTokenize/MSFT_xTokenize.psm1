# Default strings if a culture specific file cannot be imported
DATA localizedStrings
{
    # culture = "en-US"
    ConvertFrom-StringData @'
    ErrorRunningSetFunction = An error occurred while running Set-TargetResource function
    ErrorRunningTestFunction = An error occurred while running Test-TargetResource function
    Path = path = {0}
    Recursive = recurse = {0}
    SearchPattern = searchPattern = {0}
    UseTokenFiles = useTokenFiles = {0}
    Returned = Returned {0}
    ReplacingTokensParam = Replacing tokens in PSBoundParameters
    RemovingParameters = Removing parameters name and searchPattern from PSBoundParameters
    TestSingleFile = Test Single File
    Loading = Loading {0}
    NoTokensReplaced = No tokens were replaced
    TokensReplaced = Tokens replaced
    NoTokenFile = No token file found
    TestDirectory = Test Directory
    Filter = filter = {0}
    ProcessDirectory = Process Directory
    ProcessSingleFile = Process Single File
    Processing = Processing {0}
    CouldNotRead = Could not read contents of file
    Saving = Saving {0}
    ProcessingComplete = Processing complete
    ReplacingTokens = Replacing Tokens
    NullTokens = Tokens is null
    Replacing = Replacing {0} with {1}
    ReplacingFilter = Replacing filter {0} with {0}.token
    GetFiles = Get Files
    BuildHashtable = Build hashtable
    HashEntry = Key: {0}, Value: {1}
'@
}

# Load localized strings
Import-LocalizedData -BindingVariable localizedStrings -FileName MSFT_xTokenize.psd1 -ErrorAction:SilentlyContinue

function Get-TargetResource
{
   [CmdletBinding()]
   [OutputType([System.Collections.Hashtable])]
   param
   (
      [parameter(Mandatory = $true)]
      [string]
      $path,

      [bool]
      $recurse,

      [string]
      $searchPattern = "*.*",

      [Microsoft.Management.Infrastructure.CimInstance[]]
      $tokens,

      [bool]
      $useTokenFiles = $true
   )

   return @{
           Path = $path
           Recurse = $recurse
           SearchPattern = $searchPattern
           Tokens = $tokens
           UseTokenFiles = $useTokenFiles
        }
}

function Set-TargetResource
{
   [CmdletBinding()]
   param
   (
      [parameter(Mandatory = $true)]
      [string]
      $path,

      [bool]
      $recurse,

      [string]
      $searchPattern = "*.*",

      [Microsoft.Management.Infrastructure.CimInstance[]]
      $tokens,

      [bool]
      $useTokenFiles = $true
   )

   try
   {
      # Convert array into hashtable
      $tokensHashTable = ToHashtable $tokens

      # We have to remove name before splatting to ProcessDirectory
      # Pipe to Out-Null so it does not write the value of name to the 
      # screen
      Write-Debug $localizedStrings.RemovingParameters
      $PSBoundParameters.Remove("name") | Out-Null
      $PSBoundParameters.Remove("searchPattern") | Out-Null
      $PSBoundParameters.Add("filter", $searchPattern)

      # We also need to replace our tokens value with what we created
      # instead
      Write-Debug $localizedStrings.ReplacingTokensParam
      $PSBoundParameters["tokens"] = $tokensHashTable

      ProcessDirectory @PSBoundParameters
   }
   catch
   {
      $exception = $_
      Write-Verbose $localizedStrings.ErrorRunningSetFunction

      while($exception.InnerException -ne $null)
      {
         $exception = $exception.InnerException

         if($exception.message -ne $null)
         {
            Write-Verbose $exception.message
         }
      }
   }
}

function Test-TargetResource
{
   [CmdletBinding()]
   [OutputType([System.Boolean])]
   param
   (
      [parameter(Mandatory = $true)]
      [string]
      $path,

      [bool]
      $recurse,

      [string]
      $searchPattern = "*.*",

      [Microsoft.Management.Infrastructure.CimInstance[]]
      $tokens,

      [bool]
      $useTokenFiles = $true
   )

   try
   {
      Write-Debug ($localizedStrings.Path -f $path)
      Write-Debug ($localizedStrings.Recursive -f $recurse)
      Write-Debug ($localizedStrings.SearchPattern -f $searchPattern)
      Write-Debug ($localizedStrings.UseTokenFiles -f $useTokenFiles)
   
      # Convert array into hashtable
      $tokensHashTable = ToHashtable $tokens

      # We have to remove name before splatting to ProcessDirectory
      # Pipe to Out-Null so it does not write the value of name to the 
      # screen
      Write-Debug $localizedStrings.RemovingParameters
      $PSBoundParameters.Remove("name") | Out-Null
      $PSBoundParameters.Remove("searchPattern") | Out-Null
      $PSBoundParameters.Add("filter", $searchPattern)

      # We also need to replace our tokens value with what we created
      # instead
      Write-Debug $localizedStrings.ReplacingTokensParam
      $PSBoundParameters["tokens"] = $tokensHashTable

      $result = TestDirectory @PSBoundParameters

      Write-Verbose ($localizedStrings.Returned -f $result)

      return $result
   }
   catch
   {
      $exception = $_
      Write-Verbose $localizedStrings.ErrorRunningTestFunction

      while($exception.InnerException -ne $null)
      {
         $exception = $exception.InnerException

         if($exception.message -ne $null)
         {
            Write-Verbose $exception.message
         }
      }
   }
}

# The build process replaces the target file with the token file contents. So the 
# drop location will have two identical files before the transformation.
# The goal is the load the target file and load and transform the token file.  If the
# contents of the target file match the value of the transformed file or we can't find
# the token file return true. In all other cases return false.
function TestSingleFile {
    # Use CmdletBinding to pass any -verbose flags into this function
    [CmdletBinding()]
    param
    (
        [string] $path,
        [hashtable] $tokens,
        [bool] $useTokenFiles
    )

    Write-Verbose $localizedStrings.TestSingleFile
    Write-Debug ($localizedStrings.UseTokenFiles -f $useTokenFiles)
    Write-Debug ($localizedStrings.Path -f $path)

    $result = $false

    # Assume they are not using a token file.  And if so the finalFilename
    # and the provided path are the same. If a token file was used that will
    # be taken care of later.
    $finalFileName = $path
    $tokenFile = $path

    # Only remove the .token if usetokenFiles is true. There is an
    # edge condition where removing it could overwrite a file with
    # the same name minus .token that was not to be touched.  
    if($useTokenFiles)
    {
        $finalFileName = $path -replace "\.token", ""
    }
        
    $file = Get-Item -Path $finalFileName    

    if(Test-Path -Path $tokenFile)
    {
        $contents = Get-Content -Path $finalFileName

        if($useTokenFiles)
        {
            Write-Verbose ($localizedStrings.Loading -f $tokenFile)
            $tokenContents = Get-Content -Path $tokenFile
            
            $processedContents = ReplaceTokens -contents $tokenContents -tokens $tokens

            if("$processedContents" -eq "$tokens")
            {
                Write-Verbose $localizedStrings.NoTokensReplaced
            }
            else
            {
                Write-Verbose $localizedStrings.TokensReplaced
            }

            # To test when you are using a token file simply load the 
            # target file off disk and process the token file. If they match
            # after return true.
            # Testing this way gives you the added advantage of being able to 
            # just push a configuration change.  Because the token file is never
            # changed we could process it with new values and compare it to the
            # existing target file (even if the target file had been previously 
            # processed) and see if they match.  If they don't return false.
            $result = "$contents" -eq "$processedContents"

            Write-Verbose ($localizedStrings.Returned -f $result)
        }
        else
        {
            # If you are not using a token file all we can do is make sure
            # we can't find any of the tokens in the target file.
            # Assume all is well
            $result = $true

            foreach($token in $tokens.Keys)
            {
                $toFind = "*__$($token)__*"
                if($contents -like $toFind)
                {
                    $result = $false
                    break
                }                
            }
        }
    }
    else
    {
        Write-Verbose $localizedStrings.NoTokenFile
        $result = $true
    }

    $result
}

function TestDirectory {
    # Use CmdletBinding to pass any -verbose flags into this function
    [CmdletBinding()]
    param
    (
      [string] $path,
      [string] $filter,
      [hashtable] $tokens,
      [bool] $recurse,
      [bool] $useTokenFiles
    )

   Write-Debug $localizedStrings.TestDirectory
   Write-Debug ($localizedStrings.Filter -f $filter)
   Write-Debug ($localizedStrings.Path -f $path)
   Write-Debug ($localizedStrings.Recursive -f $recurse)
   Write-Debug ($localizedStrings.UseTokenFiles -f $useTokenFiles)

    $result = $true

    # We have to remove tokens before splatting to GetFiles
    # Pipe to Out-Null so it does not write the value of useTokenFiles to the 
    # screen
    $PSBoundParameters.Remove("tokens") | Out-Null

    $files = GetFiles @PSBoundParameters

    if($files.Count -ne 0)
    {
        foreach($file in $files)
        {
            Write-Verbose $file
            if((TestSingleFile -path $file.FullName -tokens $tokens -useTokenFiles $useTokenFiles) -eq $false)
            {
                $result = $false
                break;
            }
        }
    }

    return $result
}

function ProcessDirectory {
    # Use CmdletBinding to pass any -verbose flags into this function
    [CmdletBinding()]
    param
    (
      [string] $path,
      [string] $filter,
      [hashtable] $tokens,
      [bool] $recurse,
      [bool] $useTokenFiles
    )

    Write-Debug $localizedStrings.ProcessDirectory

    # We have to remove tokens before splatting to GetFiles
    # Pipe to Out-Null so it does not write the value of useTokenFiles to the 
    # screen
    $PSBoundParameters.Remove("tokens") | Out-Null

    $files = GetFiles @PSBoundParameters

    foreach($file in $files)
    {
        ProcessFile -path $file.FullName -tokens $tokens
    }
}

# Takes in the arguments from the Resource and makes sure they
# are prepared for the call to ProcessFile.
function ProcessSingleFile {
    # Use CmdletBinding to pass any -verbose flags into this function
    [CmdletBinding()]
    param
    (
        [string] $path,
        [hashtable] $tokens,
        [bool] $useTokenFiles
    )
    
    Write-Debug $localizedStrings.ProcessSingleFile
    Write-Debug ($localizedStrings.Path -f $path)
    Write-Debug ($localizedStrings.UseTokenFiles -f $useTokenFiles)

    $file = Get-Item -Path $path
    $tokenFile = $path

    if($useTokenFiles)
    {
        $tokenFile = "$($path).token"
    }

    if(Test-Path -Path $tokenFile)
    {
        ProcessFile -path $tokenFile -tokens $tokens
    }
    else
    {
        Write-Verbose $localizedStrings.NoTokenFile
    }
}

# This is where all the real work gets done.
# Takes a single file replaces the tokens and writes the output.
# It also takes care of removing and resetting the readonly flag
# on the target file.
function ProcessFile {
    # Use CmdletBinding to pass any -verbose flags into this function
    [CmdletBinding()]
    param
    (
        [string] $path,
        [hashtable] $tokens
    )

    Write-Verbose ($localizedStrings.Processing -f $path)

    $contents = Get-Content -Path $path

    if($contents -eq $null)
    {
       Write-Warning $localizedStrings.CouldNotRead
       return
    }

    $result = ReplaceTokens -contents $contents -tokens $tokens

    # Assume they are not using a token file.  And if so the finalFilename
    # and the provided path are the same. If a token file was used that will
    # be taken care of later.
    $finalFileName = $path

    # Only remove the .token if usetokenFiles is true. There is an
    # edge condition where removing it could overwrite a file with
    # the same name minus .token that was not to be touched.  
    if($useTokenFiles)
    {
        $finalFileName = $path -replace "\.token", ""
    }

    Write-Verbose ($localizedStrings.Saving -f $finalFileName)

    $file = Get-Item -Path $finalFileName
    $originalAttributes = $file.Attributes
    $desiredAttributes = RemoveReadyOnlyAttribute($originalAttributes)
    $file.Attributes = $desiredAttributes

    Set-Content -Path $finalFileName -Value $result

    $file.Attributes = $originalAttributes

    Write-Verbose $localizedStrings.ProcessingComplete
}

# This method simply finds and replaces all the tokens in the provided contents.
# The tokens provided in the hashtable do not contain the underscores so those 
# need to be added to the keys of the hashtable before they are searched for in
# the contents.
function ReplaceTokens {
    # Use CmdletBinding to pass any -verbose flags into this function
    [CmdletBinding()]
    param
    (
        [object[]] $contents,
        [hashtable] $tokens
    )

    Write-Verbose $localizedStrings.ReplacingTokens

    $result = $contents

    if($tokens -eq $null)
    {
        Write-Verbose $localizedStrings.NullTokens
        return $result
    }

    foreach($key in $($tokens.Keys)) {
        $value = $tokens[$key]
        $token = "__$($key)__"

        Write-Verbose ($localizedStrings.Replacing -f $token, $value)
        # Now replace all instances of token with value
        $result = $result -replace $token, $value
    }

    return $result
}

# When files are dropped into the drop location the ReadyOnly bit can be set. If that
# is the case it must be removed before the file can be transformed. This method makes
# it easy to only remove the ReadOnly bit leaving all the other attributes intact.  Once
# the file is transformed the original attributes should be returned.
function RemoveReadyOnlyAttribute {
    # Use CmdletBinding to pass any -verbose flags into this function
    [CmdletBinding()]
    param
    (
        [System.IO.FileAttributes] $attributes
    )

    return ($attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)) -as [System.IO.FileAttributes]
}

# This will return all the files that need to be transformed.
# If the UseTokenFiles is present only files that match the 
# filter AND have a .token file as well will be returned.
# If a folder contains
#    web.config
#    packages.config
#    web.config.token
# and filter is *.config and UseTokenFiles is false both
# web.config and packages.config would be returned.  However,
# if UseTokenFiles is true only web.config would be returned.
function GetFiles {
    # Use CmdletBinding to pass any -verbose flags into this function
    [CmdletBinding()]
    param
    (
      [string] $path,
      [string] $filter,
      [bool] $recurse,
      [bool] $useTokenFiles
    )

    Write-Debug $localizedStrings.GetFiles
    Write-Debug ($localizedStrings.Path -f $path)
    Write-Debug ($localizedStrings.Filter -f $filter)
    Write-Debug ($localizedStrings.Recursive -f $recurse)
    Write-Debug ($localizedStrings.UseTokenFiles -f $useTokenFiles)

    # We have to remove useTokenFiles before splatting to Get-ChildItem
    # Pipe to Out-Null so it does not write the value of useTokenFiles to the 
    # screen
    $PSBoundParameters.Remove("useTokenFiles") | Out-Null

    # We only want to return files not directories so add the File switch
    $PSBoundParameters.Add("file", $true)

    if($useTokenFiles)
    {
        Write-Verbose ($localizedStrings.ReplacingFilter -f $filter)
        $PSBoundParameters["filter"] = "$($filter).token"
    }

    # Return all files that match the filter if UseTokenFiles is false or only
    # files that have a .token file as well.
    Get-ChildItem @PSBoundParameters
}

# Converts a MSFT_KeyValuePair array into a PowerShell hashtable
function ToHashtable
{
   [CmdletBinding()]
   param
   (
     [Microsoft.Management.Infrastructure.CimInstance[]] $tokens
   )

   Write-Debug $localizedStrings.BuildHashtable
   
   $hashTable = @{}

   foreach($instance in $tokens)
   {
      $hashTable.Add($instance.Key, $instance.Value)
      Write-Debug ($localizedStrings.HashEntry -f $instance.Key, $instance.Value)
   }

   return $hashTable
}

Export-ModuleMember -Function *-TargetResource