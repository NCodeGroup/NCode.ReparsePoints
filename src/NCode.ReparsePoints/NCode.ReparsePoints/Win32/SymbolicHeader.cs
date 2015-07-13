using System;
using System.Runtime.InteropServices;

namespace NCode.ReparsePoints.Win32
{
	[Serializable]
	[StructLayout(LayoutKind.Sequential)]
	public struct SymbolicHeader : IReparseBuffer
	{
		public ushort SubstituteNameOffset { get; set; }
		public ushort SubstituteNameLength { get; set; }
		public ushort PrintNameOffset { get; set; }
		public ushort PrintNameLength { get; set; }
		public uint Flags { get; set; }
	}

	[Serializable]
	[StructLayout(LayoutKind.Sequential)]
	public struct ReparseData<T> : IReparseData
		where T : struct, IReparseBuffer
	{
		public uint ReparseTag { get; set; }
		public ushort ReparseDataLength { get; set; }
		public ushort Reserved { get; set; }
		public T DataBuffer { get; set; }

		IReparseBuffer IReparseData.DataBuffer { get { return DataBuffer; } }
	}

	[Serializable]
	[StructLayout(LayoutKind.Sequential)]
	public struct ReparseHeader
	{
		public uint ReparseTag;
		public ushort ReparseDataLength;
		public ushort Reserved;
	}

}