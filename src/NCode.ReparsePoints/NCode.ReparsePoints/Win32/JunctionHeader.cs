using System;
using System.Runtime.InteropServices;

namespace NCode.ReparsePoints.Win32
{
	[Serializable]
	[StructLayout(LayoutKind.Sequential)]
	public struct JunctionHeader : IReparseBuffer
	{
		public ushort SubstituteNameOffset { get; set; }
		public ushort SubstituteNameLength { get; set; }
		public ushort PrintNameOffset { get; set; }
		public ushort PrintNameLength { get; set; }
	}
}