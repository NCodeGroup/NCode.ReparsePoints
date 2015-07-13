using System;
using System.Runtime.ConstrainedExecution;
using System.Runtime.InteropServices;
using System.Security;
using Microsoft.Win32.SafeHandles;

namespace NCode.ReparsePoints.Win32
{
	[SecurityCritical]
	[SuppressUnmanagedCodeSecurity]
	internal static class NativeMethods
	{
		private const string Kernel32 = "kernel32.dll";

		[DllImport(Kernel32, SetLastError = true, CharSet = CharSet.Auto)]
		public static extern SafeFindHandle FindFirstFile(
			[In] string lpFileName,
			[Out] out WIN32_FIND_DATA lpFindFileData);

		[DllImport(Kernel32, SetLastError = true)]
		[ReliabilityContract(Consistency.WillNotCorruptState, Cer.Success)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool FindClose(
			[In] IntPtr hFindFile);

		[DllImport(Kernel32, SetLastError = true, CharSet = CharSet.Auto)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool DeviceIoControl(
			[In] SafeFileHandle hDevice,
			[In] uint dwIoControlCode,
			[In] IntPtr inBuffer,
			[In] int nInBufferSize,
			[In] IntPtr outBuffer,
			[In] int nOutBufferSize,
			[Out] out int lpBytesReturned,
			[In] IntPtr lpOverlapped);

		[DllImport(Kernel32, SetLastError = true, CharSet = CharSet.Auto)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool DeviceIoControl(
			[In] SafeFileHandle hDevice,
			[In] uint dwIoControlCode,
			[In] SafeLocalAllocHandle lpInBuffer,
			[In] int nInBufferSize,
			[In] IntPtr outBuffer,
			[In] int nOutBufferSize,
			[Out] out int lpBytesReturned,
			[In] IntPtr lpOverlapped);

		[DllImport(Kernel32, SetLastError = true, CharSet = CharSet.Auto)]
		public static extern SafeFileHandle CreateFile(
			[In] string lpFileName,
			[In] AccessRights dwDesiredAccess,
			[In] FileShareMode dwShareMode,
			[In] IntPtr lpSecurityAttributes,
			[In] FileCreationDisposition dwCreationDisposition,
			[In] FileAttributeFlags dwFlagsAndAttributes,
			[In] IntPtr hTemplateFile);

		[DllImport(Kernel32, SetLastError = true, CharSet = CharSet.Auto)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool CreateHardLink(
			string lpFileName,
			string lpExistingFileName,
			IntPtr lpSecurityAttributes);

		[DllImport(Kernel32, SetLastError = true)]
		[ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
		public static extern SafeLocalAllocHandle LocalAlloc(
			[In] AllocFlags flags,
			[In] IntPtr cb);

		[DllImport(Kernel32, SetLastError = true, EntryPoint = "LocalAlloc")]
		[ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
		public static extern SafeLocalAllocBuffer LocalAllocBuffer(
			[In] AllocFlags flags,
			[In] IntPtr cb);

		[DllImport(Kernel32, SetLastError = true)]
		[ReliabilityContract(Consistency.WillNotCorruptState, Cer.Success)]
		public static extern IntPtr LocalFree(
			[In] IntPtr handle);

	}
}