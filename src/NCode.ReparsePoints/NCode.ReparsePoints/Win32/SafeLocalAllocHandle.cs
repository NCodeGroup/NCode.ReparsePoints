using System;
using System.Runtime.InteropServices;
using System.Security;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace NCode.ReparsePoints.Win32
{
	[SecurityCritical]
	internal class SafeLocalAllocHandle : SafeHandleZeroOrMinusOneIsInvalid
	{
		#region Static Members

		public static SafeLocalAllocHandle Allocate(int cb)
		{
			return Allocate(new IntPtr(cb));
		}

		public static SafeLocalAllocHandle Allocate(IntPtr cb)
		{
			return NativeMethods.LocalAlloc(AllocFlags.Fixed, cb);
		}

		#endregion

		protected SafeLocalAllocHandle()
			: base(true)
		{
			// do not delete this ctor
			// it is required for pinvoke
		}

		public SafeLocalAllocHandle(IntPtr handle)
			: base(true)
		{
			SetHandle(handle);
		}

		public virtual int Write(byte[] buffer, int targetOffset)
		{
			Marshal.Copy(buffer, 0, handle + targetOffset, buffer.Length);
			return buffer.Length;
		}

		public virtual int Write<T>(T value, int targetOffset)
			where T : struct
		{
			var length = Marshal.SizeOf(value);
			Marshal.StructureToPtr(value, handle + targetOffset, false);
			return length;
		}

		public virtual int Write(string value, int targetOffset, Encoding encoding)
		{
			var bytes = encoding.GetBytes(value);
			return Write(bytes, targetOffset);
		}

		[SecurityCritical]
		protected override bool ReleaseHandle()
		{
			return NativeMethods.LocalFree(handle) == IntPtr.Zero;
		}

	}
}