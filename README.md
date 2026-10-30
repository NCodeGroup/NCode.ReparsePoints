<a href="https://teamcity.bixbots.com/viewType.html?buildTypeId=NCodeReparsePoints_Build&guest=1" target="_blank">
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
````csharp
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
````
## Interface
````csharp
	/// <summary>
	/// Represents the type of reparse point such as a hard link, junction (aka
	/// soft link), or symbolic link.
	/// </summary>
	[Serializable]
	public enum LinkType
	{
		/// <summary>
		/// Represents an unknown reparse point type.
		/// </summary>
		Unknown = 0,

		/// <summary>
		/// Represents a file <c>hard link</c>.
		/// </summary>
		/// <remarks>
		/// Technically not a reparse point.
		/// </remarks>
		HardLink,

		/// <summary>
		/// Represents a directory <c>junction</c> (aka soft link).
		/// </summary>
		Junction,

		/// <summary>
		/// Represents a <c>symbolic link</c> to either a file or folder.
		/// </summary>
		/// <remarks>
		/// In order to create symbolic links, the current user must either be an
		/// administrator running with elevated privileges or a non-admin user that
		/// has the SeCreateSymbolicLinkPrivilege right in local security policy.
		/// </remarks>
		Symbolic
	}

	/// <summary>
	/// Contains the methods to create and inspect win32 file and folder reparse
	/// points such as hard links, junctions (aka soft links), and symbolic links.
	/// </summary>
	/// <remarks>
	/// Technically speaking, hard links are not reparse points but this library
	/// supports them too.
	/// </remarks>
	public interface IReparsePointProvider
	{
		/// <summary>
		/// Given a path, determines the type of reparse point.
		/// </summary>
		/// <param name="path">The path to inspect.</param>
		/// <returns>A <see cref="LinkType"/> enumeration.</returns>
		LinkType GetLinkType(string path);

		/// <summary>
		/// Given a path, returns the information about a reparse point.
		/// </summary>
		/// <param name="path">The path to inspect.</param>
		/// <returns>A <see cref="ReparseLink"/> that contains the information
		/// about a reparse point.</returns>
		ReparseLink GetLink(string path);

		/// <summary>
		/// Creates a new reparse point such as a hard link, junction (aka soft
		/// link), or symoblic link.
		/// </summary>
		/// <remarks>
		/// In order to create symbolic links, the current user must either be an
		/// administrator running with elevated privileges or a non-admin user that
		/// has the SeCreateSymbolicLinkPrivilege right in local security policy.
		/// </remarks>
		/// <param name="path">The path of reparse point to create.</param>
		/// <param name="target">The target for the reparse point.</param>
		/// <param name="type">A <see cref="LinkType"/> enumeration that specifies
		/// the type of reparse point to create.</param>
		void CreateLink(string path, string target, LinkType type);
	}

	/// <summary>
	/// Contains the information about a reparse point.
	/// </summary>
	public struct ReparseLink
	{
		/// <summary>
		/// Contains the <see cref="FileAttributes"/> of a reparse point.
		/// </summary>
		public FileAttributes Attributes { get; set; }

		/// <summary>
		/// Contains the <see cref="LinkType"/> of a reparse point.
		/// </summary>
		public LinkType Type { get; set; }

		/// <summary>
		/// Contains the target of a reparse point.
		/// </summary>
		/// <remarks>
		/// The target for a hard link cannot be determined so this member will
		/// always be <c>null</c> for hard links.
		/// </remarks>
		public string Target { get; set; }
	}
````
