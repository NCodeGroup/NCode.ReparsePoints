namespace NCode.ReparsePoints.Win32
{
	internal static class Win32Constants
	{
		public const int MaxPath = 260;

		public const int ERROR_INSUFFICIENT_BUFFER = 122;
		public const int ERROR_NOT_A_REPARSE_POINT = 4390;

		public const uint IO_REPARSE_TAG_MOUNT_POINT = 0xA0000003;
		public const uint IO_REPARSE_TAG_SYMLINK = 0xA000000C;

		public const uint FSCTL_SET_REPARSE_POINT = 0x000900A4;
		public const uint FSCTL_GET_REPARSE_POINT = 0x000900A8;

		public const string NonInterpretedPathPrefix = "\\??\\";

		public static readonly string[] DosDevicePrefixes =
		{
			"\\??\\",
			"\\DosDevices\\",
			"\\Global??\\"
		};

	}
}