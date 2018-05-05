function vcpkgHasProperty([Parameter(Mandatory=$true)][AllowNull()]$object, [Parameter(Mandatory=$true)]$propertyName)
{
    if ($object -eq $null)
    {
        return $false
    }

    return [bool]($object.psobject.Properties | where { $_.Name -eq "$propertyName"})
}
