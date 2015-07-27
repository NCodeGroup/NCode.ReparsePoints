using System;

namespace NCode.ReparsePoints
{
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
		Symbolic
	}
}