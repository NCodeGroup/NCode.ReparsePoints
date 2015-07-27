using System;
using System.Runtime.InteropServices;

namespace NCode.ReparsePoints.Win32
{
	[Serializable]
	[StructLayout(LayoutKind.Sequential)]
	internal struct ReparseHeader
	{
		public uint ReparseTag;
		public ushort ReparseDataLength;
		public ushort Reserved;
		// next in memory:
		// ReparseData
		// SubstituteName
		// PrintName
	}

	internal interface IReparseData
	{
		ushort SubstituteNameOffset { get; }
		ushort SubstituteNameLength { get; }
		ushort PrintNameOffset { get; }
		ushort PrintNameLength { get; }
	}

	[Serializable]
	[StructLayout(LayoutKind.Sequential)]
	internal struct JunctionData : IReparseData
	{
		public ushort SubstituteNameOffset { get; set; }
		public ushort SubstituteNameLength { get; set; }
		public ushort PrintNameOffset { get; set; }
		public ushort PrintNameLength { get; set; }
	}

	[Serializable]
	[StructLayout(LayoutKind.Sequential)]
	internal struct SymbolicData : IReparseData
	{
		public ushort SubstituteNameOffset { get; set; }
		public ushort SubstituteNameLength { get; set; }
		public ushort PrintNameOffset { get; set; }
		public ushort PrintNameLength { get; set; }
		public uint Flags { get; set; }
	}
}