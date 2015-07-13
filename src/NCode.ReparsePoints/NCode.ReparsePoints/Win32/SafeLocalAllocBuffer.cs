using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Security;

namespace NCode.ReparsePoints.Win32
{
	[SecurityCritical]
	internal class SafeLocalAllocBuffer : SafeBuffer
	{
		#region Static Members

		public static SafeLocalAllocBuffer Allocate(int cb)
		{
			return Allocate(new IntPtr(cb));
		}

		public static SafeLocalAllocBuffer Allocate(IntPtr cb)
		{
			SafeLocalAllocBuffer handle;
			RuntimeHelpers.PrepareConstrainedRegions();
			try { }
			finally
			{
				handle = NativeMethods.LocalAllocBuffer(AllocFlags.Fixed, cb);
			}
			handle.Initialize((ulong)(long)cb);
			return handle;
		}

		#endregion

		protected SafeLocalAllocBuffer()
			: base(true)
		{
			// do not delete this ctor
			// it is required for pinvoke
		}

		public SafeLocalAllocBuffer(IntPtr handle)
			: base(true)
		{
			SetHandle(handle);
		}

		[SecurityCritical]
		protected override bool ReleaseHandle()
		{
			return NativeMethods.LocalFree(handle) == IntPtr.Zero;
		}

	}
}