using System;

namespace NCode.ReparsePoints
{
	[Serializable]
	public enum LinkType
	{
		Unknown = 0,
		HardLink,
		Junction,
		Symbolic
	}
}