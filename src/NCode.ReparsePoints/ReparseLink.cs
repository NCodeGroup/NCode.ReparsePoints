using System.IO;

namespace NCode.ReparsePoints
{
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
}