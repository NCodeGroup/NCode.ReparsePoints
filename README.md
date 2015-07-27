<a href="https://teamcity.bixbots.com/viewType.html?buildTypeId=NCodeReparsePoints_Build&guest=1">
  <img src="https://img.shields.io/teamcity/https/teamcity.bixbots.com/s/NCodeReparsePoints_Build.svg?label=TeamCity" />
</a>

# NCode.ReparsePoints

This library provides an API to create and inspect Win32 file and folder reparse points such as hard links, junctions (aka soft links), and symbolic links.

## Link Types

* Hard Link
* Junction (also known as Soft Link)
* Symbolic Link

## Hard Link

Technically speaking a `Hard Link` is not really a Reparse Point on Win32 systems. Instead they are a type of file pointer supported since Windows XP and Server 2003.

* Files only
* Supported since:
	* Windows XP
	* Windows Server 2003
* Must be on same volume
* Must be on same computer
* No special privileges required (other than file security)

See [MSDN](https://msdn.microsoft.com/en-us/library/windows/desktop/aa365006.aspx) for more information.

## Junction

* Directories only
* Supported since:
	* Windows XP
	* Windows Server 2003
* Resolved by server (vs client)
* Can be on different volume
* Must be on same computer
* No special privileges required (other than folder security)

See [MSDN](https://msdn.microsoft.com/en-us/library/windows/desktop/aa365006.aspx) for more information.

## Symbolic Link

* Files or Directories
* Supported since:
	* Windows Vista
	* Windows Server 2008
* Resolved by client (vs server)
* Can be on different volume
* Can be on different computer
* Requires the `SeCreateSymbolicLinkPrivilege` right:
	* Administrator accounts has this right by default, but they must be running as elevated.
	* Non-administrator accounts need to be added to Local Security Policy.

See [MSDN](https://msdn.microsoft.com/en-us/library/windows/desktop/aa365680.aspx) for more information.

## Example Usage

	using NCode.ReparsePoints;
	internal static class Program
	{
		private static void Main()
		{
		    var provider = ReparsePointFactory.Provider;
		    provider.CreateLink("D:\NewJunction", "C:\SourceDir", LinkType.Junction);
		
		    var link = provider.GetLink("D:\NewJunction");
		    Console.WriteLine("Type: {0}", link.Type);
		    Console.WriteLine("Target: {0}", link.Target);
		}
	}
