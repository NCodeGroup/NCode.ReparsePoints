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

		[DllImport(Kernel32, SetLastError = true, CharSet = CharSet.Unicode)]
		public static extern SafeFindHandle FindFirstFile(
			[In] string lpFileName,
			[Out] out Win32FindData lpFindFileData);

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
			[In] SafeLocalAllocHandle lpInBuffer,
			[In] int nInBufferSize,
			[In] SafeLocalAllocHandle lpOutBuffer,
			[In] int nOutBufferSize,
			[Out] out int lpBytesReturned,
			[In] IntPtr lpOverlapped);

		[DllImport(Kernel32, SetLastError = true, CharSet = CharSet.Unicode)]
		public static extern SafeFileHandle CreateFile(
			[In] string lpFileName,
			[In] AccessRights dwDesiredAccess,
			[In] FileShareMode dwShareMode,
			[In] IntPtr lpSecurityAttributes,
			[In] FileCreationDisposition dwCreationDisposition,
			[In] FileAttributeFlags dwFlagsAndAttributes,
			[In] IntPtr hTemplateFile);

		[DllImport(Kernel32, SetLastError = true, CharSet = CharSet.Unicode)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool CreateHardLink(
			[In] string lpFileName,
			[In] string lpExistingFileName,
			[In] IntPtr lpSecurityAttributes);

		[DllImport(Kernel32, SetLastError = true, CharSet = CharSet.Unicode)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool CreateSymbolicLink(
			[In] string lpSymlinkFileName,
			[In] string lpTargetFileName,
			[In] SymbolicLinkFlag dwFlags);

		[DllImport(Kernel32, SetLastError = true)]
		[ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
		public static extern SafeLocalAllocHandle LocalAlloc(
			[In] AllocFlags flags,
			[In] IntPtr cb);

		[DllImport(Kernel32, SetLastError = true)]
		[ReliabilityContract(Consistency.WillNotCorruptState, Cer.Success)]
		public static extern IntPtr LocalFree(
			[In] IntPtr handle);

	}
}