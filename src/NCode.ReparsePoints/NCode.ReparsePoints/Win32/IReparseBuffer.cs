namespace NCode.ReparsePoints.Win32
{
	public interface IReparseBuffer
	{
		ushort SubstituteNameOffset { get; }
		ushort SubstituteNameLength { get; }
		ushort PrintNameOffset { get; }
		ushort PrintNameLength { get; }
	}

	public interface IReparseData
	{
		uint ReparseTag { get; }
		ushort ReparseDataLength { get; }
		ushort Reserved { get; }
		IReparseBuffer DataBuffer { get; }
	}

}